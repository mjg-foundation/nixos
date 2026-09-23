import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { StatusPlugin } from "./status-plugin.mjs"

const root = mkdtempSync(join(tmpdir(), "local-status-test-"))
process.env.LOCAL_CODE_STATUS_FILE = join(root, "status.json")
try {
  const hooks = await StatusPlugin()
  const state = () => JSON.parse(readFileSync(process.env.LOCAL_CODE_STATUS_FILE)).status
  const event = (type, properties = {}) => hooks.event({ event: { type, properties: { sessionID: "a", ...properties } } })
  assert.equal(state(), "waiting")
  await event("session.status", { status: { type: "busy" } })
  assert.equal(state(), "working")
  await event("permission.asked", { id: "p1" })
  await event("permission.v2.asked", { id: "p2" })
  await event("session.status", { status: { type: "busy" } })
  assert.equal(state(), "waiting") // Busy does not hide pending approval.
  await event("permission.replied", { requestID: "p1" })
  assert.equal(state(), "waiting") // A second request is still outstanding.
  await event("permission.v2.replied", { requestID: "p2" })
  assert.equal(state(), "working")
  await event("question.v2.asked", { id: "q" })
  assert.equal(state(), "waiting")
  await event("question.v2.rejected", { requestID: "q" })
  await event("session.error")
  assert.equal(state(), "waiting")
  await event("session.status", { status: { type: "retry" } })
  assert.equal(state(), "working")
  await event("session.idle")
  assert.equal(state(), "waiting")
  await event("session.status", { sessionID: "child", status: { type: "busy" } })
  assert.equal(state(), "working")
  await event("session.deleted", { sessionID: "child" })
  assert.equal(state(), "waiting")
  console.log("PASS: permission/question precedence, multiple prompts, error, retry, idle and child sessions")
} finally {
  delete process.env.LOCAL_CODE_STATUS_FILE
  rmSync(root, { recursive: true, force: true })
}
