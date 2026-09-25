"""Contract tests for bin/linear. Run: python3 -m unittest discover -s tests"""
import importlib.machinery
import importlib.util
import io
import pathlib
import sys
import unittest

# Loading bin/linear as a module must not leave a __pycache__ beside the script.
sys.dont_write_bytecode = True

_path = pathlib.Path(__file__).resolve().parent.parent / "bin" / "linear"
_loader = importlib.machinery.SourceFileLoader("linear_cli", str(_path))
_spec = importlib.util.spec_from_loader("linear_cli", _loader)
linear = importlib.util.module_from_spec(_spec)
_loader.exec_module(linear)

TEAMS = {"teams": {"nodes": [
    {"id": "t-clio", "key": "CLIO", "name": "Clio", "states": {"nodes": [
        {"id": "s-todo", "name": "Todo", "type": "unstarted"},
        {"id": "s-done", "name": "Done", "type": "completed"},
    ]}},
    {"id": "t-lev", "key": "LEV", "name": "Leverage", "states": {"nodes": [
        {"id": "s-lev-done", "name": "Done", "type": "completed"},
    ]}},
]}}


class FakeLinear:
    """Answers each query by the first registered substring it contains."""

    def __init__(self, answers):
        self.answers = answers
        self.calls = []

    def __call__(self, query, variables=None):
        self.calls.append((query, variables or {}))
        for needle, answer in self.answers:
            if needle in query:
                return answer(variables or {}) if callable(answer) else answer
        raise AssertionError(f"unexpected query: {query[:80]}")

    def mutation(self, name):
        return [v for q, v in self.calls if name + "(" in q]


def run(argv, fake):
    out = io.StringIO()
    code = linear.main(argv, gql=fake, out=out, cache=None)
    return code, out.getvalue()


class LinearCliTest(unittest.TestCase):
    def test_update_resolves_a_state_name_within_the_issues_team(self):
        fake = FakeLinear([
            ("teams(", TEAMS),
            ("issueUpdate(", {"issueUpdate": {"success": True, "issue": {"identifier": "LEV-9", "url": "u"}}}),
            ("issue(", {"issue": {"id": "i-9", "identifier": "LEV-9", "team": {"id": "t-lev", "key": "LEV"}}}),
        ])
        code, _ = run(["update", "LEV-9", "--state", "done"], fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.mutation("issueUpdate")[0]["input"], {"stateId": "s-lev-done"})

    def test_blocked_by_creates_the_relation_from_the_blocker(self):
        ids = {"CLIO-1": "i-1", "LEV-2": "i-2"}
        fake = FakeLinear([
            ("issueRelationCreate(", {"issueRelationCreate": {"success": True}}),
            ("issue(", lambda v: {"issue": {"id": ids[v["id"]], "identifier": v["id"], "team": {"id": "t", "key": "X"}}}),
        ])
        code, _ = run(["relate", "CLIO-1", "blocked-by", "LEV-2"], fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.mutation("issueRelationCreate")[0]["input"],
                         {"issueId": "i-2", "relatedIssueId": "i-1", "type": "blocks"})

    def test_issue_view_shows_both_relation_directions_and_caps_comments(self):
        issue = {
            "id": "i-1", "identifier": "CLIO-1", "title": "Title", "url": "https://l/CLIO-1",
            "description": "Body text.", "priority": 3, "estimate": None, "dueDate": None,
            "updatedAt": "2026-09-26T01:00:00.000Z", "state": {"name": "Blocked"},
            "assignee": {"name": "Chi Feng"}, "team": {"key": "CLIO"}, "project": None,
            "cycle": None, "labels": {"nodes": []}, "parent": None, "children": {"nodes": []},
            "attachments": {"nodes": []}, "documents": {"nodes": []},
            "createdAt": "2026-09-25T01:00:00.000Z", "creator": {"name": "Chi Feng"},
            "relations": {"nodes": [{"type": "related", "relatedIssue": {"identifier": "DATA-4", "title": "Rel", "state": {"name": "Todo"}}}]},
            "inverseRelations": {"nodes": [{"type": "blocks", "issue": {"identifier": "LEV-2", "title": "Blocker", "state": {"name": "Backlog"}}}]},
            "comments": {"nodes": [
                {"id": f"{i}" * 8 + "-x", "createdAt": f"2026-09-2{i}T00:00:00.000Z", "user": {"name": "A"},
                 "parent": None, "body": f"c{i} " + "x" * 900}
                for i in (4, 3, 2, 1)
            ]},
        }
        fake = FakeLinear([("issue(", {"issue": issue})])
        code, text = run(["issue", "CLIO-1"], fake)
        self.assertEqual(code, 0)
        self.assertIn("blocked by: LEV-2 Backlog Blocker", text)
        self.assertIn("related: DATA-4 Todo Rel", text)
        self.assertIn("comments(first:4)", fake.calls[0][0])
        self.assertNotIn("c1 ", text)
        self.assertLess(text.index("c2 "), text.index("c4 "))
        self.assertIn("44444444", text)
        self.assertNotIn("x" * 900, text)

    def test_list_open_mine_filters_on_state_type_assignee_and_team(self):
        fake = FakeLinear([("teams(", TEAMS), ("issues(", {"issues": {"nodes": [], "pageInfo": {"hasNextPage": False}}})])
        code, _ = run(["list", "--open", "--mine", "--team", "clio"], fake)
        self.assertEqual(code, 0)
        flt = fake.calls[-1][1]["filter"]["and"]
        self.assertIn({"state": {"type": {"nin": ["completed", "canceled", "duplicate"]}}}, flt)
        self.assertIn({"assignee": {"isMe": {"eq": True}}}, flt)
        self.assertIn({"team": {"id": {"eq": "t-clio"}}}, flt)

    def test_list_state_names_match_case_insensitively_and_keep_open(self):
        fake = FakeLinear([("issues(", {"issues": {"nodes": [], "pageInfo": {"hasNextPage": False}}})])
        run(["list", "--open", "--state", "done,in review"], fake)
        self.assertEqual(fake.calls[0][1]["filter"]["and"], [
            {"state": {"type": {"nin": ["completed", "canceled", "duplicate"]}}},
            {"state": {"or": [{"name": {"eqIgnoreCase": "done"}}, {"name": {"eqIgnoreCase": "in review"}}]}},
        ])

    def test_a_write_the_api_reports_unsuccessful_exits_nonzero(self):
        fake = FakeLinear([
            ("issueSubscribe(", {"issueSubscribe": {"success": False}}),
            ("issue(", {"issue": {"id": "i-1", "identifier": "CLIO-1", "team": {"id": "t", "key": "CLIO"}}}),
        ])
        err = io.StringIO()
        self.assertEqual(linear.main(["subscribe", "CLIO-1"], gql=fake, out=io.StringIO(), err=err, cache=None), 1)

    def test_reply_accepts_the_short_comment_id_the_issue_view_prints(self):
        fake = FakeLinear([
            ("commentCreate(", {"commentCreate": {"success": True, "comment": {"url": "u"}}}),
            ("issue(", {"issue": {"id": "i-1", "identifier": "CLIO-1", "team": {"id": "t", "key": "CLIO"},
                                  "comments": {"nodes": [{"id": "b5d3b95f-1111"}, {"id": "0a0a0a0a-2222"}]}}}),
        ])
        code, _ = run(["comment", "CLIO-1", "thanks", "--reply", "b5d3b95f"], fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.mutation("commentCreate")[0]["input"]["parentId"], "b5d3b95f-1111")

    def test_graphql_errors_exit_nonzero_with_the_message(self):
        def fail(_q, _v=None):
            raise linear.LinearError("Invalid scope: `write` required")
        err = io.StringIO()
        code = linear.main(["comment", "CLIO-1", "hi"], gql=fail, out=io.StringIO(), err=err, cache=None)
        self.assertEqual(code, 1)
        self.assertIn("Invalid scope", err.getvalue())


if __name__ == "__main__":
    unittest.main()
