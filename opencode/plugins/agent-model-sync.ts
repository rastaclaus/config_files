// Keeps each session on the model declared for its active agent.
//
// OpenCode V2 resolves a session model once (stored session model, else the
// catalog default) and never reconsults `agents.<id>.model`, so switching
// between plan and build leaves the previous model in place. This plugin runs
// on prompt admission — before model resolution — and switches the session to
// the active agent's model whenever the agent changed.
//
// A model picked manually for the session is never overridden: the plugin
// remembers both the agent and the model it last applied, so any other model
// on the session is treated as the user's choice and left alone until the next
// agent switch.
export default {
  id: "agent-model-sync",
  async setup(ctx) {
    // `variant` is optional on a model ref; an omitted variant and the literal
    // "default" mean the same thing (upstream #57821).
    const normalize = (model) =>
      model && { providerID: model.providerID, id: model.id, variant: model.variant ?? "default" }

    const same = (a, b) => {
      if (!a || !b) return a === b
      const x = normalize(a)
      const y = normalize(b)
      return x.providerID === y.providerID && x.id === y.id && x.variant === y.variant
    }

    const apply = async (sessionID, model) => {
      await ctx.session.switchModel({
        sessionID,
        model: {
          providerID: model.providerID,
          id: model.id,
          variant: model.variant ?? "default",
        },
      })
    }

    await ctx.session.hook("prompt", async (event) => {
      const session = await ctx.session.get({ sessionID: event.sessionID })
      if (!session.agent) return

      const key = `agent-model-sync:${event.sessionID}`
      const raw = await ctx.storage.get(key)
      // Legacy records stored the bare agent id.
      const previous = typeof raw === "string" ? { agent: raw, model: undefined } : raw

      const agent = (await ctx.agent.get({ agentID: session.agent }))?.data
      const want = agent?.model
      const current = session.model
      const state = { agent: session.agent, model: current ?? null }

      // The agent declares no model: leave the session alone, just track it.
      if (!want) {
        if (!same(previous?.model, current)) await ctx.storage.set(key, state)
        return
      }

      // First sync for this session. A model already chosen belongs to the
      // user (or predates the plugin), so only fill in an empty selection.
      if (!previous) {
        if (current) {
          if (!same(current, want)) await ctx.storage.set(key, state)
          return
        }
        await apply(event.sessionID, want)
        await ctx.storage.set(key, { agent: session.agent, model: normalize(want) })
        return
      }

      // The model changed since the last sync: manual pick, never override.
      if (!same(previous.model, current)) {
        await ctx.storage.set(key, state)
        return
      }

      // Agent changed and the model did not follow it: apply the agent's model.
      if (previous.agent !== session.agent) {
        if (same(current, want)) {
          await ctx.storage.set(key, state)
          return
        }
        await apply(event.sessionID, want)
        await ctx.storage.set(key, { agent: session.agent, model: normalize(want) })
        return
      }

      await ctx.storage.set(key, state)
    })
  },
}
