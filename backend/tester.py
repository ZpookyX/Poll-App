import pytest
from backend import server
from backend.server import db, Poll, PollOption, Vote


# set up app for testing with in-memory sqlite
@pytest.fixture()
def app():
    server.app.config.update({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:"
    })
    with server.app.app_context():
        db.create_all()  # create tables
        yield server.app
        db.session.remove()
        db.drop_all()

# get test client from app
@pytest.fixture()
def client(app):
    return app.test_client()

# test creating a poll; checks if poll saved correctly
def test_create_poll(client, login):
    url = "/polls"
    payload = {
        "question": "what's your favorite color?",
        "options": ["red", "blue", "green"]
    }
    response = client.post(url, json=payload)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    data = response.get_json()
    assert "poll_id" in data  # poll_id should be returned
    poll_id = data["poll_id"]
    poll = Poll.query.get(poll_id)
    assert poll is not None  # poll should exist
    assert poll.question == payload["question"]

# test retrieving a poll
def test_retrieve_poll(client, app):
    # create a poll directly in db
    poll = Poll(question="what's your favorite animal?")
    db.session.add(poll)
    db.session.flush()  # get poll_id

    # add two options
    option1 = PollOption(poll_id=poll.poll_id, option_text="cat")
    option2 = PollOption(poll_id=poll.poll_id, option_text="dog")
    db.session.add(option1)
    db.session.add(option2)
    db.session.commit()

    # get the poll
    url = f"/polls/{poll.poll_id}"
    response = client.get(url)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    data = response.get_json()
    assert "question" in data
    assert data["question"] == "what's your favorite animal?"
    assert "options" in data
    assert len(data["options"]) == 2

    # try a non-existent poll
    non_existent_id = poll.poll_id + 100
    url = f"/polls/{non_existent_id}"
    response = client.get(url)
    assert response.status_code == 404, f"expected 404, got {response.status_code}"
    data = response.get_json()
    assert "message" in data
    assert data["message"] == "poll not found"

# test that poll deletion works
def test_remove_poll(client, login):
    poll = Poll(question="test poll for deletion")
    db.session.add(poll)
    db.session.commit()

    # delete the poll
    url = f"/polls/{poll.poll_id}"
    response = client.delete(url)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"

    # try deleting non-existent poll
    non_existent_id = poll.poll_id + 100
    url = f"/polls/{non_existent_id}"
    response = client.delete(url)
    assert response.status_code == 404, f"expected 404, got {response.status_code}"
    data = response.get_json()
    assert "message" in data
    assert data["message"] == "poll not found, can't be removed"

# test voting functionality and prevention of duplicate votes
def test_vote_poll(client, login):
    poll = Poll(question="what's your favorite season?")
    db.session.add(poll)
    db.session.flush()

    # create two options
    option1 = PollOption(poll_id=poll.poll_id, option_text="summer")
    option2 = PollOption(poll_id=poll.poll_id, option_text="winter")
    db.session.add(option1)
    db.session.add(option2)
    db.session.commit()
    url = f"/polls/{poll.poll_id}/vote"
    payload = {"option_id": option1.option_id}

    # first vote should work
    response = client.post(url, json=payload)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"

    # second vote should be blocked
    response = client.post(url, json=payload)
    assert response.status_code == 400, f"expected 400, got {response.status_code}"

# test retrieving all polls
def test_all_polls(client, app):
    poll1 = Poll(question="poll one?")
    poll2 = Poll(question="poll two?")
    db.session.add(poll1)
    db.session.add(poll2)
    db.session.commit()
    url = "/polls"
    response = client.get(url)

    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    data = response.get_json()

    # check both polls are in response
    assert any(p["poll_id"] == poll1.poll_id for p in data)
    assert any(p["poll_id"] == poll2.poll_id for p in data)

# test retrieving polls the user hasn't voted in
def test_unvoted_polls(client, login):
    poll1 = Poll(question="poll to vote?")
    poll2 = Poll(question="poll not voted?")
    db.session.add(poll1)
    db.session.add(poll2)
    db.session.flush()

    # add options for both polls
    option1a = PollOption(poll_id=poll1.poll_id, option_text="option a")
    option1b = PollOption(poll_id=poll1.poll_id, option_text="option b")
    option2a = PollOption(poll_id=poll2.poll_id, option_text="option c")
    option2b = PollOption(poll_id=poll2.poll_id, option_text="option d")
    db.session.add_all([option1a, option1b, option2a, option2b])
    db.session.commit()

    # vote in poll1
    vote = Vote(poll_id=poll1.poll_id, option_id=option1a.option_id, user_id=login["id"])
    db.session.add(vote)
    db.session.commit()
    url = "/polls/unvoted"
    response = client.get(url)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    data = response.get_json()

    # should be only one poll left that user hasn't voted in
    assert len(data) == 1, "there should be one unvoted poll"
    assert data[0]["poll_id"] == poll2.poll_id
