"""
Notification service — fan-out writes, read feed, mark-as-read.

Design decisions documented inline.
"""
from __future__ import annotations

import logging
from typing import Any

from firebase_admin import firestore
from google.cloud.firestore_v1 import WriteBatch

# Snapshot at most 2 actors per doc. Additional actors are captured in
# actorCount so the UI can render "and N others" without extra reads.
_MAX_ACTOR_SNAPSHOT = 2

# Firestore batches are capped at 500 operations total.
# Each recipient fan-out consumes 2 ops (notification doc + counter bump),
# so we flush well below the limit to leave headroom for future additions.
_BATCH_FLUSH_AT = 400


def _flush(batch: WriteBatch, db: firestore.Client) -> WriteBatch:
    """Commit the batch and return a fresh one."""
    batch.commit()
    return db.batch()


def _build_doc(
    *,
    recipient_id: str,
    notif_type: str,
    actors: list[dict[str, str]],
    actor_count: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    """
    Build a notification document dict.

    SERVER_TIMESTAMP is used for createdAt instead of a Python datetime so
    that ordering is clock-skew-safe across multiple backend instances.
    We build a groupKey so the Flutter client can collapse duplicates later.
    """
    entity_id = (
        payload.get("postId")
        or payload.get("scheduleId")
        or "generic"
    )
    return {
        "recipientId": recipient_id,
        "type": notif_type,
        "isRead": False,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "actors": actors[:_MAX_ACTOR_SNAPSHOT],
        "actorCount": actor_count,
        "payload": payload,
        "groupKey": f"{notif_type}::{entity_id}",
    }


# ──────────────────────────────────────────────────────────────────────────────
# Public write helpers (called from api_router or other services after events)
# ──────────────────────────────────────────────────────────────────────────────

def notify_post_reply(
    db: firestore.Client,
    *,
    post_id: str,
    comment_id: str,
    post_author_id: str,
    replier_uid: str,
    replier_display_name: str,
    replier_photo_url: str,
    preview_text: str,
    logger: logging.Logger,
) -> None:
    """
    Write a single post_reply notification for the post author.

    We still use a batch (not a bare .set()) so the notification doc and the
    unread counter increment are atomic — no partial state on network failure.
    """
    if post_author_id == replier_uid:
        return  # never self-notify

    post_snap = db.collection("posts").document(post_id).get()
    if post_snap.exists and bool((post_snap.to_dict() or {}).get("is_notifications_muted", False)):
        return  # post author muted notifications for this post

    notif_ref = (
        db.collection("users")
        .document(post_author_id)
        .collection("notifications")
        .document()  # auto-ID
    )
    user_ref = db.collection("users").document(post_author_id)

    batch = db.batch()
    batch.set(
        notif_ref,
        _build_doc(
            recipient_id=post_author_id,
            notif_type="post_reply",
            actors=[{
                "uid": replier_uid,
                "displayName": replier_display_name,
                "photoUrl": replier_photo_url,
            }],
            actor_count=1,
            payload={
                "postId": post_id,
                "commentId": comment_id,
                # Cap preview length to keep doc size small.
                "previewText": preview_text[:120],
            },
        ),
    )
    # Increment(1) is an atomic server-side operation — avoids the
    # read-modify-write race that would occur if we fetched, incremented
    # in Python, and wrote back.
    batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
    batch.commit()

    logger.info(
        "post_reply notification written",
        extra={"recipient": post_author_id, "post": post_id},
    )


def notify_post_heart(
    db: firestore.Client,
    *,
    post_id: str,
    post_author_id: str,
    liker_uid: str,
    liker_display_name: str,
    liker_photo_url: str,
    logger: logging.Logger,
) -> None:
    """Write a post_heart notification for the post author."""
    if post_author_id == liker_uid:
        return  # never self-notify

    post_snap = db.collection("posts").document(post_id).get()
    if post_snap.exists and bool((post_snap.to_dict() or {}).get("is_notifications_muted", False)):
        return  # post author muted notifications for this post

    notif_ref = (
        db.collection("users")
        .document(post_author_id)
        .collection("notifications")
        .document()
    )
    user_ref = db.collection("users").document(post_author_id)

    batch = db.batch()
    batch.set(
        notif_ref,
        _build_doc(
            recipient_id=post_author_id,
            notif_type="post_heart",
            actors=[{
                "uid": liker_uid,
                "displayName": liker_display_name,
                "photoUrl": liker_photo_url,
            }],
            actor_count=1,
            payload={"postId": post_id},
        ),
    )
    batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
    batch.commit()
    logger.info(
        "post_heart notification written",
        extra={"recipient": post_author_id, "post": post_id},
    )


def notify_comment_heart(
    db: firestore.Client,
    *,
    post_id: str,
    comment_id: str,
    comment_author_id: str,
    liker_uid: str,
    liker_display_name: str,
    liker_photo_url: str,
    logger: logging.Logger,
) -> None:
    """Write a comment_heart notification for the comment author."""
    if comment_author_id == liker_uid:
        return  # never self-notify

    notif_ref = (
        db.collection("users")
        .document(comment_author_id)
        .collection("notifications")
        .document()
    )
    user_ref = db.collection("users").document(comment_author_id)

    batch = db.batch()
    batch.set(
        notif_ref,
        _build_doc(
            recipient_id=comment_author_id,
            notif_type="comment_heart",
            actors=[{
                "uid": liker_uid,
                "displayName": liker_display_name,
                "photoUrl": liker_photo_url,
            }],
            actor_count=1,
            payload={"postId": post_id, "commentId": comment_id},
        ),
    )
    batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
    batch.commit()
    logger.info(
        "comment_heart notification written",
        extra={"recipient": comment_author_id, "comment": comment_id},
    )


def notify_group_post_shared(
    db: firestore.Client,
    *,
    sharer_uid: str,
    sharer_display_name: str,
    sharer_photo_url: str,
    co_sharer_uid: str,
    co_sharer_display_name: str,
    co_sharer_photo_url: str,
    recipient_ids: list[str],
    post_count: int,
    logger: logging.Logger,
) -> None:
    """
    Fan-out: write one notification doc per recipient.

    Fan-out on write is the canonical Firestore pattern for read-heavy feeds:
    - Each user reads only their own subcollection → O(1) per user.
    - Avoiding a single shared doc eliminates complex security rules and
      prevents the 1-write/s hot-spot limit on a single document.

    We chunk writes into batches of _BATCH_FLUSH_AT ops to stay safely under
    Firestore's 500-operations-per-batch hard limit.
    """
    actors = [
        {"uid": sharer_uid, "displayName": sharer_display_name, "photoUrl": sharer_photo_url},
        {"uid": co_sharer_uid, "displayName": co_sharer_display_name, "photoUrl": co_sharer_photo_url},
    ]

    batch = db.batch()
    ops = 0

    for recipient_id in recipient_ids:
        if recipient_id in (sharer_uid, co_sharer_uid):
            continue  # skip the actors themselves

        notif_ref = (
            db.collection("users")
            .document(recipient_id)
            .collection("notifications")
            .document()
        )
        user_ref = db.collection("users").document(recipient_id)

        batch.set(
            notif_ref,
            _build_doc(
                recipient_id=recipient_id,
                notif_type="group_post_shared",
                actors=actors,
                actor_count=2,
                payload={"postCount": post_count},
            ),
        )
        batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
        ops += 2

        if ops >= _BATCH_FLUSH_AT:
            batch = _flush(batch, db)
            ops = 0
            logger.debug("Flushed mid fan-out batch")

    if ops > 0:
        batch.commit()

    logger.info(
        "group_post_shared fan-out complete",
        extra={"recipients": len(recipient_ids), "posts": post_count},
    )


def notify_connection_request(
    db: firestore.Client,
    *,
    recipient_uid: str,
    requester_uid: str,
    requester_display_name: str,
    requester_photo_url: str,
    connection_id: str,
    logger: logging.Logger,
) -> None:
    """
    Write a connection_request notification to users/{recipient_uid}/notifications.

    Payload carries the connection_id so the Flutter client can surface
    Accept / Decline actions directly from the notification tile without
    an extra fetch.
    """
    if recipient_uid == requester_uid:
        return  # never self-notify

    notif_ref = (
        db.collection("users")
        .document(recipient_uid)
        .collection("notifications")
        .document()
    )
    user_ref = db.collection("users").document(recipient_uid)

    batch = db.batch()
    batch.set(
        notif_ref,
        _build_doc(
            recipient_id=recipient_uid,
            notif_type="connection_request",
            actors=[{
                "uid": requester_uid,
                "displayName": requester_display_name,
                "photoUrl": requester_photo_url,
            }],
            actor_count=1,
            payload={"connectionId": connection_id},
        ),
    )
    batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
    batch.commit()
    logger.info(
        "connection_request notification written",
        extra={"recipient": recipient_uid, "connection": connection_id},
    )


def notify_connection_accepted(
    db: firestore.Client,
    *,
    requester_uid: str,
    acceptor_uid: str,
    acceptor_display_name: str,
    acceptor_photo_url: str,
    connection_id: str,
    logger: logging.Logger,
) -> None:
    """
    Notify the original requester that their connection request was accepted.
    """
    if requester_uid == acceptor_uid:
        return  # never self-notify

    notif_ref = (
        db.collection("users")
        .document(requester_uid)
        .collection("notifications")
        .document()
    )
    user_ref = db.collection("users").document(requester_uid)

    batch = db.batch()
    batch.set(
        notif_ref,
        _build_doc(
            recipient_id=requester_uid,
            notif_type="connection_accepted",
            actors=[{
                "uid": acceptor_uid,
                "displayName": acceptor_display_name,
                "photoUrl": acceptor_photo_url,
            }],
            actor_count=1,
            payload={"connectionId": connection_id},
        ),
    )
    batch.update(user_ref, {"unreadNotifCount": firestore.Increment(1)})
    batch.commit()
    logger.info(
        "connection_accepted notification written",
        extra={"recipient": requester_uid, "connection": connection_id},
    )


# ──────────────────────────────────────────────────────────────────────────────
# Read / mark-read
# ──────────────────────────────────────────────────────────────────────────────

def fetch_notifications(
    db: firestore.Client,
    *,
    user_id: str,
    limit: int = 40,
    logger: logging.Logger,
) -> list[dict[str, Any]]:
    """
    Return the most recent notifications for a user, ordered newest-first.

    Reads from the user subcollection — no cross-user query, no security-rule
    complexity, and Firestore serves this from the local nearest region node.

    Notifications that reference a deleted post are silently dropped and
    auto-deleted so they never resurface.
    """
    docs = (
        db.collection("users")
        .document(user_id)
        .collection("notifications")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(max(1, min(limit, 100)))  # clamp: never more than 100
        .stream()
    )

    raw: list[tuple[Any, dict[str, Any]]] = []
    for doc in docs:
        data = doc.to_dict() or {}
        raw.append((doc, data))

    # ── Batch existence check for notifications that reference a post ─────────
    # Collect unique postIds so we make at most one Firestore read per post.
    _POST_TYPES = {"post_reply", "post_heart", "comment_heart"}
    post_ids: set[str] = set()
    for _, data in raw:
        if data.get("type") in _POST_TYPES:
            pid = (data.get("payload") or {}).get("postId", "")
            if pid:
                post_ids.add(pid)

    # Fetch all referenced post documents in one round-trip using db.get_all().
    existing_post_ids: set[str] = set()
    if post_ids:
        refs = [db.collection("posts").document(pid) for pid in post_ids]
        for snap in db.get_all(refs):
            if snap.exists:
                existing_post_ids.add(snap.id)

    # ── Build result, auto-deleting orphaned notifications ───────────────────
    result = []
    orphan_refs = []
    for doc, data in raw:
        notif_type = data.get("type", "unknown")
        if notif_type in _POST_TYPES:
            pid = (data.get("payload") or {}).get("postId", "")
            if pid and pid not in existing_post_ids:
                # Referenced post was deleted — queue for cleanup.
                orphan_refs.append(doc.reference)
                continue

        created_at = data.get("createdAt")
        created_at_str = (
            created_at.isoformat() if hasattr(created_at, "isoformat") else ""
        )
        result.append({
            "id": doc.id,
            "recipient_id": data.get("recipientId", ""),
            "type": notif_type,
            "actors": data.get("actors", []),
            "actor_count": data.get("actorCount", 0),
            "payload": data.get("payload", {}),
            "is_read": data.get("isRead", False),
            "created_at": created_at_str,
            "group_key": data.get("groupKey"),
        })

    # Delete orphaned notification docs in a batch (fire-and-forget).
    if orphan_refs:
        try:
            batch = db.batch()
            for ref in orphan_refs:
                batch.delete(ref)
            batch.commit()
            logger.info(
                "auto-deleted orphaned notifications",
                extra={"user": user_id, "count": len(orphan_refs)},
            )
        except Exception:
            logger.exception("Failed to auto-delete orphaned notifications")

    return result


def mark_notifications_read(
    db: firestore.Client,
    *,
    user_id: str,
    notification_ids: list[str],
    logger: logging.Logger,
) -> None:
    """
    Mark the given notification docs as read and reset the unread badge.

    We use update() (not set()) to touch only the isRead field — set() without
    merge=True would silently overwrite all other fields.
    We do NOT use a transaction here because isRead=True is idempotent:
    re-running on the same IDs is safe, and a transaction would lock all docs
    for the full RTT, causing contention on dual-device scenarios.
    """
    batch = db.batch()
    ops = 0

    for notif_id in notification_ids:
        ref = (
            db.collection("users")
            .document(user_id)
            .collection("notifications")
            .document(notif_id)
        )
        batch.update(ref, {"isRead": True})
        ops += 1

        if ops >= _BATCH_FLUSH_AT:
            batch = _flush(batch, db)
            ops = 0

    if ops > 0:
        batch.commit()

    # Reset badge to 0 rather than decrement by len(ids) — self-heals any
    # counter drift caused by previous partial failures.
    db.collection("users").document(user_id).update({"unreadNotifCount": 0})

    logger.info(
        "notifications marked read",
        extra={"user": user_id, "count": len(notification_ids)},
    )


def delete_notifications_for_post(
    db: firestore.Client,
    *,
    post_id: str,
    logger: logging.Logger,
) -> None:
    """
    Delete every notification whose payload.postId matches the deleted post.

    Uses a collection group query across all users' notification subcollections
    so no per-user iteration is needed. Deletes are batched to stay within
    Firestore's 500-operation-per-batch limit.
    """
    docs = (
        db.collection_group("notifications")
        .where(filter=firestore.FieldFilter("payload.postId", "==", post_id))
        .stream()
    )

    batch = db.batch()
    ops = 0

    for doc in docs:
        batch.delete(doc.reference)
        ops += 1
        if ops >= _BATCH_FLUSH_AT:
            batch = _flush(batch, db)
            ops = 0

    if ops > 0:
        batch.commit()

    logger.info(
        "deleted notifications for post",
        extra={"post_id": post_id, "count": ops},
    )


def delete_all_notifications(
    db: firestore.Client,
    *,
    user_id: str,
    logger: logging.Logger,
) -> None:
    """
    Delete all notifications for a single user and reset their unread badge.
    """
    docs = (
        db.collection("users")
        .document(user_id)
        .collection("notifications")
        .stream()
    )

    batch = db.batch()
    ops = 0

    for doc in docs:
        batch.delete(doc.reference)
        ops += 1
        if ops >= _BATCH_FLUSH_AT:
            batch = _flush(batch, db)
            ops = 0

    if ops > 0:
        batch.commit()

    db.collection("users").document(user_id).update({"unreadNotifCount": 0})

    logger.info(
        "deleted all notifications",
        extra={"user": user_id, "count": ops},
    )


def patch_notification_payload_status(
    db: firestore.Client,
    *,
    user_id: str,
    notification_id: str,
    status: str,
    logger: logging.Logger,
) -> None:
    """
    Update payload.status on a connection-request notification so the
    accepted/declined state survives app restarts (persisted in Firestore).
    """
    ref = (
        db.collection("users")
        .document(user_id)
        .collection("notifications")
        .document(notification_id)
    )
    if not ref.get().exists:
        return
    ref.update({"payload.status": status})
    logger.info(
        "patched notification payload status",
        extra={"user": user_id, "notification_id": notification_id, "status": status},
    )


def delete_single_notification(
    db: firestore.Client,
    *,
    user_id: str,
    notification_id: str,
    logger: logging.Logger,
) -> None:
    """
    Delete a single notification document and decrement the unread badge
    if the notification was unread.
    """
    ref = (
        db.collection("users")
        .document(user_id)
        .collection("notifications")
        .document(notification_id)
    )
    doc = ref.get()
    if not doc.exists:
        return

    data = doc.to_dict() or {}
    was_unread = not data.get("isRead", False)

    ref.delete()

    if was_unread:
        user_ref = db.collection("users").document(user_id)
        user_ref.update({"unreadNotifCount": firestore.Increment(-1)})

    logger.info(
        "deleted single notification",
        extra={"user": user_id, "notification_id": notification_id},
    )
