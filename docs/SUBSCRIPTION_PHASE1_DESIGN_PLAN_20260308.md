# Ascendra Subscription Phase 1 Design And Execution Plan

## Goal

Ship a credible first-stage subscription MVP without pretending the product is already a full BetterUp-style platform.

Phase 1 is intentionally narrow:

- Launch `Free + Pro`
- Add `Teams Pilot` as a manual sales motion
- Do not build full enterprise administration yet
- Do not bundle human coaching yet

## Product Scope

### Free

- Core AI coaching access
- Limited usage
- One default premium feel, but not the full premium toolkit

### Pro

- Unlock the full premium self-serve experience
- Prioritize features users immediately understand and feel

Recommended premium entitlements for Phase 1:

- Voice access
- Session summaries
- Access to the second coaching persona

These were chosen because they are legible and easy to market. They also avoid over-claiming capabilities that still rely on mocks or missing backend endpoints.

## Business Scope

### Public pricing

- Free
- Pro at $29/month or $249/year

### Sales-led pilot

- Teams Pilot is contact-only
- Manual onboarding is acceptable
- Manual reporting is acceptable
- Shared billing and seat operations can initially be handled operationally

## Engineering Principles

1. Implement a real subscription state model now, even if billing is mocked initially.
2. Keep entitlement checks centralized instead of scattering plan logic across views.
3. Prefer visible, reversible gating over hidden dead ends.
4. Build the UI flow now so StoreKit or Stripe can be connected later without redesigning the app.

## Phase 1 Deliverables

### Must ship

- Persistent app-level subscription state
- A paywall / subscription screen
- Clear upgrade entry points from locked features
- Entitlement checks for:
  - voice
  - session summaries
  - second persona
- Current plan display inside profile

### Should ship

- Local upgrade preview for development and investor demos
- Upgrade context copy such as "Unlock voice coaching"
- Lightweight analytics hooks for paywall and upgrade actions

### Explicitly out of scope

- Real App Store billing
- Refund handling
- Remote entitlement sync
- Team admin dashboard
- Seat provisioning UI
- Human coach booking flow

## Design Direction

The subscription experience should feel premium and specific, not generic:

- Position the offer as executive coaching, not productivity software
- Highlight outcome language: clarity, stakeholder navigation, decision support
- Use current design language, but introduce a stronger premium moment on the paywall
- Show one clear CTA, not a crowded pricing comparison matrix

## Implementation Plan

### Step 1

Create a lightweight subscription domain model:

- plan enum
- entitlement checks
- feature labels
- upgrade CTA copy

### Step 2

Store subscription state in `AppState` with persistence to `UserDefaults`.

### Step 3

Build a subscription screen with:

- current plan
- Pro value proposition
- feature list
- upgrade action
- downgrade / reset action for preview builds

### Step 4

Wire upgrade entry points from locked features:

- Voice button in chat
- Session summary action
- Persona selection for locked persona
- Profile plan management section

### Step 5

Build and verify the iOS app with `xcodebuild`.

## Risks

### Risk 1

The product may look more monetized than it is if billing is still local-only.

Mitigation:

- Treat this as subscription infrastructure and demo-ready gating, not final billing completion.

### Risk 2

Goals and voice experience are not fully production-grade yet.

Mitigation:

- Gate only the most defensible premium features now.
- Do not market goal tracking as a core paid promise until the backend is real.

### Risk 3

Teams Pilot could create product pressure too early.

Mitigation:

- Keep it sales-led and manual until Pro conversion and retention are understood.

## Go / No-Go Criteria

Phase 1 is ready for a controlled launch when:

- The app can display and persist current plan state
- Locked premium features consistently route to the paywall
- The paywall clearly explains the Free to Pro upgrade
- The app builds cleanly
- Investor demos can switch plans cleanly without hidden state bugs
