// Keeps each session on the model declared for its active agent.
//
// OpenCode V2 resolves a session model once (stored session model, else the
// catalog default) and never reconsults `agents.<id>.model`, so switching
// between plan and build leaves the previous model in place. This plugin runs
// on prompt admission — before model resolution — and switches the session to
// the active agent's model whenever the agent changed, or the session has no
// model yet. A model picked manually for the session survives until the next
// agent switch.
export default {
  id: "agent-model-sync",
  async setup(ctx) {
    await ctx.session.hook("prompt", async (event) => {
      const session = await ctx.session.get({ sessionID: event.sessionID })
      if (!session.agent) return

      const key = `agent-model-sync:${event.sessionID}`
      const previous = await ctx.storage.get(key)
      if (previous === session.agent && session.model) return

      const agent = (await ctx.agent.get({ agentID: session.agent }))?.data
      const want = agent?.model
      if (!want) return

      await ctx.session.switchModel({
        sessionID: event.sessionID,
        model: {
          providerID: want.providerID,
          id: want.id,
          variant: want.variant ?? "default",
        },
      })
      await ctx.storage.set(key, session.agent)
    })
  },
}
