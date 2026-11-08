# Native Swedish app

Use the Finnish native iOS app as the design and behavior reference. This project uses SwiftUI for iOS and Kotlin/Jetpack Compose for Android; do not migrate it to React Native.

Keep native application IDs separate from Finnish. Preserve stable `sv-` word IDs and learner progress as the collection grows. Both platforms consume the generated `Resources/` content from `Content/catalog.json`; run `node Tools/build_content.mjs` after content changes. Pending translations must not enter study. Use only reviewed Swedish artwork; each finished card image includes the exact Swedish word, English meaning, memory link where useful, and Swedish example sentence.

Keep changes local until the user asks for a push. The intended remote is `git@github.com:maixuanlinh/Swedish3000Flashcards.git`. Do not use the `codex/` prefix for branches.

Never copy Finnish signing credentials, store product identities, or learner databases into this project. Store listing, final branding, and privacy/support publication remain release tasks.

When the user asks to continue content production, complete the entire current letter in that turn, including authored content, reviewed illustrations, resource generation and verification. Internal batches are checkpoints, not turn-completion milestones. If a real blocker prevents completion, report the blocker and exact remaining work.

The user now prefers sustained content production across letter boundaries in a single turn until the available token budget is exhausted. Preserve card quality and the direct connection between the Swedish word, English sense, example and scene. If a clear teaching idea cannot be found, explain the specific difficulty and return to letter-by-letter collaboration. This preference supersedes stopping after one completed letter.
