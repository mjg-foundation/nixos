// OpenCode 1.17.x session/permission events, including the v2 prompt events.
// Writes only to the per-launch file in the already-mounted private home.
import { mkdirSync, renameSync, writeFileSync } from "node:fs"
import { dirname } from "node:path"

export const StatusPlugin = async () => {
  const path = process.env.LOCAL_CODE_STATUS_FILE
  if (!path) return {}
  const sessions = new Map()
  function publish() {
    const values = [...sessions.values()]
    const pending = values.some(s => s.pending.size)
    const working = values.some(s => s.working)
    const status = pending ? "waiting" : working ? "working" : "waiting"
    const reason = pending ? "permission or question" : working ? "running" : "idle or stopped"
    try {
      mkdirSync(dirname(path), { recursive: true, mode: 0o700 })
      writeFileSync(`${path}.tmp`, JSON.stringify({ status, reason }), { mode: 0o600 })
      renameSync(`${path}.tmp`, path)
    } catch { /* Status reporting must not interrupt coding work. */ }
  }
  publish()
  return {
    event: async ({ event }) => {
      const p = event.properties ?? {}
      const id = p.sessionID ?? p.info?.id
      if (!id) return
      const s = sessions.get(id) ?? { working: false, pending: new Set() }
      const type = event.type.replace(".v2.", ".")
      if (type === "permission.asked" || type === "question.asked") {
        s.pending.add(p.id)
      } else if (["permission.replied", "question.replied", "question.rejected"].includes(type)) {
        s.pending.delete(p.requestID)
      } else if (type === "session.status") {
        s.working = ["busy", "retry"].includes(p.status?.type)
      } else if (["session.idle", "session.error", "session.deleted"].includes(type)) {
        s.working = false
        s.pending.clear()
      } else return
      if (type === "session.deleted") sessions.delete(id)
      else sessions.set(id, s)
      publish()
    },
  }
}

export default { id: "local-code-waybar-status", server: StatusPlugin }
