#!/usr/bin/env python3
"""
seed_demo.py

Create a demo "friend" user with two polls and one comment.
Run via:
    python seed_demo.py
"""

from datetime import datetime, timedelta
from server import app, db, User, Poll, PollOption, Comment


def seed_demo_user():
    # Create a demo friend
    friend = User(username="friend@example.com")
    db.session.add(friend)
    db.session.commit()
    print(f"Created friend with user.id = {friend.id}")

    # First poll
    p1 = Poll(
        question="What’s your favorite color?",
        creator_id=friend.id,
        timeleft=datetime.now() + timedelta(days=1)
    )
    db.session.add(p1)
    db.session.flush()  # get p1.poll_id
    db.session.add(PollOption(poll_id=p1.poll_id, option_text="Red"))
    db.session.add(PollOption(poll_id=p1.poll_id, option_text="Blue"))

    # Second poll
    p2 = Poll(
        question="Tea or coffee?",
        creator_id=friend.id,
        timeleft=datetime.now() + timedelta(days=1)
    )
    db.session.add(p2)
    db.session.flush()
    db.session.add(PollOption(poll_id=p2.poll_id, option_text="Tea"))
    db.session.add(PollOption(poll_id=p2.poll_id, option_text="Coffee"))

    db.session.commit()
    print(f"Created polls: {p1.poll_id}, {p2.poll_id}")

    # Add a comment on the first poll
    comment = Comment(
        comment_text="I personally love Blue!",
        author_id=friend.id,
        poll_id=p1.poll_id,
        parent_comment_id=None
    )
    db.session.add(comment)
    db.session.commit()
    print(f"Added comment.id = {comment.comment_id} to poll.id = {p1.poll_id}")


if __name__ == "__main__":
    with app.app_context():
        seed_demo_user()
