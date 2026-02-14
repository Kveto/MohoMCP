# MohoMCP — Vision, Strategy & Brainstorming Notes

*Captured: 2026-02-14*

---

## 1. What Exists Today

MohoMCP is a working MCP bridge that gives AI full control over Moho Pro 14 animation software. It provides:

- **26 structured API tools** for reading/writing document structure, layers, bones, animation keyframes, mesh data
- **Batch execution** collapsing N operations into a single IPC round-trip (~300ms total vs ~300ms each)
- **Visual perception** via scene rendering and full UI window capture (screenshot)
- **Physical input** via mouse clicks, drags, and keyboard shortcuts — the application cannot distinguish this from a human user
- **Static knowledge resources** with Moho's complete keyboard shortcuts and tool reference

### The Dual Control Plane (Key Differentiator)

The system operates through two complementary control planes:

1. **API layer** — structured, fast, reliable. The application knows it's being programmed.
2. **Perception + input layer** — screenshots, mouse, keyboard. The application has no idea it's being controlled by AI.

No professional software exposes 100% of its functionality through its scripting API. The hybrid approach covers both the fast API path for structured operations and falls back to visual perception and GUI input for everything else. Critically, the AI can **verify its own work** by capturing screenshots after making changes — closing the feedback loop.

This pattern is generalizable: every application has a GUI, not every application has a good API.

---

## 2. Commercial Assessment

### Market Reality

- Moho's user base is small (tens of thousands) — caps revenue if the product stays Moho-only
- The MCP bridge itself (plumbing) is necessary but not what users pay for
- Users pay for **workflows**: "I describe a motion and it happens"

### Viable Commercialization Paths

1. **Moho plugin** ($30-50) — "AI Animation Assistant for Moho," targeting hobbyist/indie market
2. **Generalize to multiple tools** — the architecture (file-based IPC + MCP bridge + perception/input layer) works for any application with a scripting API or just a GUI: Blender, After Effects, Toon Boom, Houdini, SolidWorks, AutoCAD
3. **Service/subscription model** — open-source bridge, paid curated AI workflow templates (walk cycles, lip sync, secondary motion)
4. **License to Lost Marble** — approach them with a working demo for first-party Moho integration

### Window of Opportunity

There is currently a gap between what AI can do and what existing software exposes to AI. This gap will narrow as AI systems gain native tool use and GUI-operating agents mature. However, **the gap shifts rather than closes** — when basic integration becomes commoditized, value moves up to orchestration, workflow design, domain expertise, and adaptive teaching. Positioning at that higher level now is strategic.

---

## 3. The Abstraction Layer Vision

### Core Concept

An **orchestration layer** where a human provides high-level creative direction (via voice and touch) and the system decomposes that into multi-step, multi-tool execution plans. The human stays in the creative director role. The AI becomes the technical operator.

### The Gap It Fills

Currently people either:
- Manually operate each tool themselves (slow, expert-only)
- Use simple automation/macros within a single tool (limited)
- Use AI for generation from scratch (no control over existing projects)

The abstraction layer sits in the empty space between these: **AI-orchestrated multi-tool workflows with human creative direction via natural language and gesture.**

### Target User

People who have **creative vision but not technical expertise across all the tools needed to realize it.** A filmmaker who can't animate. An animator who can't compose music. A game designer who can't model. The system handles the technical execution; the user brings the creative intent.

### Applicable Domains

The pattern — high-level tasks decomposed into rich sets of steps interconnecting complex software — applies to:
- Animation production (current proof point)
- Video production (editing, compositing, effects)
- Game development (modeling, rigging, level design)
- Graphic design (multi-tool print/web workflows)
- CAD/engineering (design, simulation, documentation)
- Music/audio production (composition, mixing, mastering)

---

## 4. The Adaptive Teaching Layer

### Concept

An independent teaching component that:
- Understands the user's current knowledge level and starting abilities
- Meets the user where they are, not where the tool assumes they should be
- Guides patiently, adapting explanation depth and autonomy level
- Evolves by gaining knowledge from independent resources (tutorials, documentation, technique guides, advanced user patterns)

### Why It Matters

- **Solves the adoption problem** — users don't know enough to ask the right questions. The teacher can say *"the motion looks abrupt — would you like me to smooth the transitions? Here's what that means..."* and then actually do it.
- **Creates natural skill progression** — Day one: "make the character walk" (system does everything). Day thirty: "use ease_out on the hip rotation, I want the weight to feel heavy" (user has learned through doing). The system gradually shifts from doing to advising.
- **Bidirectional learning** — the system learns user preferences and skill level; the teaching layer evolves by ingesting new resources and distilling advanced user patterns into guidance for beginners.

### Self-Learning Capabilities (Achievable Near-Term)

- Observe which batch patterns / workflow sequences the user requests most and pre-suggest them
- Learn individual preferences (e.g., "this animator always uses ease_out on first keyframes")
- Detect repetitive follow-up actions and offer to automate them (e.g., always taking a screenshot after setting transforms)
- Discover which explanation styles work best for specific user profiles
- Source and integrate new domain knowledge from external resources

None of this requires training a new model — it's **preference learning and pattern recognition on top of existing AI capabilities** with a lightweight learning layer over the orchestration system.

---

## 5. The Tablet Control Surface

### Concept

A dedicated tablet application that serves as the **creative direction interface**, physically separate from the workstation running the professional tools.

### Design Principle: Organized by Functionality, Not by Tools

Current software UIs are organized around tools and actions (toolbars, menus, property panels) — designed for direct manipulation. AI-orchestrated workflows need an interface organized around **intent and workflow state.**

Instead of "here are 50 bone tools," the surface shows:
- What the AI is currently doing (live orchestration status)
- What it has done (visual history with undo granularity)
- What it needs from you (decisions, creative choices, approvals)
- What you can do next (contextual suggestions for current workflow stage)

### Proposed Functional Organization

| Surface | Concern | Examples |
|---------|---------|----------|
| **Story** | Narrative & structure | Scenario, scenes, timing, narrative flow |
| **Motion** | Movement & physics | Character poses, movement, dynamics |
| **Look** | Visual style | Colors, lighting, camera, style |
| **Sound** | Audio | Dialogue, music, effects |
| **Review** | Evaluation | Playback, comparison, approval |

Each is a *creative concern*, not a software feature. The system translates creative direction into the right API calls, mouse clicks, keyboard shortcuts, across whichever tools are involved.

### Why Tablet + Voice

- **Physically separate** — main screen shows the application, tablet is the command surface. No fighting for screen space. (This mirrors how film directors work — they don't sit at the editing station.)
- **Touch is natural for creative direction** — scrubbing timelines, adjusting sliders, approving/rejecting results, zooming into sections. These are directorial gestures.
- **Voice + touch combined** — "Make the arm swing wider" (voice for intent) while scrubbing the timeline on the tablet to show exactly which section (touch for specificity). Neither alone is as powerful as both together.

### Differentiation

Nobody is building this. Current approaches are either AI inside existing tool UIs (Copilot-style sidebars) or new generative tools from scratch (Runway, Kling). Nobody is building an **external creative direction surface** that orchestrates existing professional tools.

---

## 6. Content Production Strategy

### Concept

Produce educational videos for kids using the MohoMCP toolchain, serving multiple purposes simultaneously.

### Three Value Streams from One Activity

1. **The educational content itself** — YouTube, educational platforms, schools. Revenue stream independent of whether the tooling becomes a product.
2. **Behind-the-scenes / process content** — "How I made an educational cartoon using AI and voice commands." Interesting to the creative-tech audience. Also serves as a product demo.
3. **Tooling improvement** — every production friction point becomes a product improvement. Every episode makes the system better.

### Why This Is the Right Starting Point

- **Forces real usage** — nothing exposes tooling gaps faster than trying to produce something real
- **Generates proof** — demonstrable output, not hypothetical capability
- **Realistic complexity** — educational kids' content needs clarity and engagement, not Pixar-level polish. Right quality bar for AI-assisted production today.
- **The production process is the demo** — potential users, partners, and collaborators can see exactly what the system does

### Practical First Step

Start with one short video. Two minutes, one simple concept, one character. Use the MohoMCP setup. Document every friction point. The first video will teach more about what to build next than any amount of planning.

---

## 7. Multi-Card Strategy

### Assets in Play

| Card | Status | Risk Level |
|------|--------|------------|
| MohoMCP as working product / proof of skill | Built, functional | Low |
| Abstraction layer pattern for other tools | Architecture proven | Medium |
| Educational content production | Ready to start | Low |
| Adaptive teaching interface | Conceptual | Higher |
| Tablet control surface | Conceptual | Higher |
| Professional AI experience & credibility | Established (years) | Low |

### Strategic Logic

Not all cards need to succeed. One or two gaining traction is sufficient, and the others reinforce or pivot into the next opportunity. The concrete work (MohoMCP, content production) feeds the more ambitious concepts (teaching layer, tablet surface) with real-world data and experience.

### Timeline Awareness

- **Near-term (now):** The experience of bridging AI to professional tools is itself a closing-window asset. Few people have both years of AI hands-on work and the instinct to build practical integration infrastructure.
- **Medium-term (1-2 years):** Basic tool integration will commoditize. Value shifts to orchestration, workflow design, domain expertise, teaching.
- **Longer-term:** AI systems will operate GUIs natively. The differentiator becomes the workflow intelligence, adaptive teaching, and creative direction interface — not the bridge itself.

**Build concrete things. Ship them. Let the market signal which card wins.**

---

## 8. Key Technical Insights to Preserve

1. **Batch execution** is critical for usability — the difference between "AI assistant that kinda works" and one that feels responsive. Latency optimization is a product feature.

2. **The dual control plane** (API + perception/input) is the generalizable pattern. Every desktop application can be controlled this way, regardless of whether it has a scripting API.

3. **The AI can verify its own work** via screenshots. API-only integrations are blind. The feedback loop (act -> perceive -> evaluate -> adjust) is what makes AI-orchestrated workflows reliable.

4. **MCP as protocol** means building one interface that works with any AI provider. This is a significant architectural advantage over custom integrations.

5. **File-based IPC** solved the hard problem of communicating with an application (Moho) that has no network capabilities. This pattern applies to any application with only a filesystem-accessible scripting environment.

---

*This document captures brainstorming between the developer and Claude during the MohoMCP batch_execute implementation session. Ideas range from immediately actionable to longer-term vision. The strategic value is in the combination, not any single element.*
