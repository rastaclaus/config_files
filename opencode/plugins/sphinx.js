// Sphinx lifecycle integration for OpenCode 1.x and 2.x.
// The generated (managed) V1 file lived at ~/.config/opencode/plugins/sphinx.js;
// this dual export keeps V1 working through server() and adds V2 hooks.
import { appendFileSync } from "node:fs";
import { Plugin } from "@opencode/plugin";
import {
  TERMINAL_GUIDANCE,
  browserHandoff,
  registerOpenCodeIntegration,
} from "file:///home/artems/.local/lib/node_modules/sphinx-understand/src/lifecycle-integrations.js";

const HOME = "/home/artems/.config/sphinx";
const DEBUG = process.env.SPHINX_PLUGIN_DEBUG === "1";
const LOG = "/tmp/opencode/sphinx-plugin.log";
// Sphinx waits up to 25 minutes for an answer; the host's 2 minute default
// would kill the Git process before the human can finish the questionnaire.
const GIT_TIMEOUT_MS = Number(process.env.SPHINX_SHELL_TIMEOUT_MS) || 26 * 60 * 1000;
const GIT_COMMAND = /\bgit\b[^\n]*\b(push|commit|merge|rebase)\b/;

const debug = (...parts) => {
  if (!DEBUG) return;
  try {
    appendFileSync(LOG, `${new Date().toISOString()} ${parts.map(String).join(" ")}\n`);
  } catch {}
};

const sessionId = value =>
  typeof value === "string" && /^[A-Za-z0-9_-]{1,200}$/.test(value) ? value : undefined;

const scopedEnv = () => ({ ...process.env, SPHINX_HOME: HOME });

export default {
  ...Plugin.define({
    id: "sphinx",
    async setup(ctx) {
      debug("setup", JSON.stringify({ directory: ctx.location?.directory }));
      if (process.env.SPHINX_EVALUATOR === "1") return;

      const directory = ctx.location.directory;
      // shell.create.before carries no session id; the context hook runs for the
      // model call that precedes the shell tool, so it is the freshest session.
      let currentSession;

      await ctx.shell.hook("create.before", event => {
        event.env.SPHINX_HOME = HOME;
        if (currentSession) event.env.SPHINX_OPENCODE_SESSION = currentSession;
        // Git checkpoints block until the human answers; keep the original
        // process alive instead of letting the host cancel it mid-interview.
        if (GIT_COMMAND.test(event.command ?? "")) event.timeout = Math.max(event.timeout ?? 0, GIT_TIMEOUT_MS);
        debug("shell", JSON.stringify({ keys: Object.keys(event), command: event.command?.slice(0, 120), timeout: event.timeout }));
      });

      await ctx.session.hook("context", event => {
        currentSession = sessionId(event.sessionID) ?? currentSession;
        debug("context", JSON.stringify({ sessionID: event.sessionID, system: event.system?.length }));
        const present = event.system.some(
          part => part?.type === "text" && part.text?.includes("Sphinx checks the human"),
        );
        if (!present) event.system.push({ type: "text", text: TERMINAL_GUIDANCE });
      });

      await ctx.tool.hook("execute.after", async event => {
        if (!["shell", "bash"].includes(event.tool)) return;
        debug("after", JSON.stringify({
          tool: event.tool,
          status: event.status,
          sessionID: event.sessionID,
          content: Array.isArray(event.result?.content) ? "array" : typeof event.result?.content,
          output: typeof event.result?.output,
          error: event.error ? Object.keys(event.error) : undefined,
        }));

        let notice;
        try {
          notice = await browserHandoff({
            cwd: directory,
            host: "opencode",
            hostSession: sessionId(event.sessionID),
            env: scopedEnv(),
          });
        } catch (error) {
          debug("handoff-error", error?.message);
          notice = "Sphinx could not inspect its checkpoint queue. Run sphinx doctor and sphinx check in your own terminal.";
        }
        if (!notice) return;
        debug("notice", JSON.stringify(notice.slice(0, 200)));

        if (event.status === "completed") {
          const result = event.result ?? (event.result = {});
          if (Array.isArray(result.content)) result.content.push({ type: "text", text: notice });
          else if (typeof result.content === "string") result.content = `${result.content}\n\n${notice}`;
          else if (typeof result.output === "string") result.output = `${result.output}\n\n${notice}`;
          else result.content = notice;
        }
      });
    },
  }),

  // V1 entrypoint: the original managed implementation, unchanged.
  async server(context) {
    return registerOpenCodeIntegration(context, { home: HOME });
  },
};
