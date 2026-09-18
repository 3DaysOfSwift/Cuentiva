# Working on Cuentiva

Read [the architecture guide](docs/architecture.md), then follow one feature from its view to its repository. Keep changes small enough to explain without narrating the development session.

- Use names that describe the user action or domain rule. Prefer a few clear statements over several operations compressed onto one line.
- Keep a screen and its view model together. Put business rules in the feature manager and external storage behind a repository protocol.
- Add abstraction when it has a concrete responsibility or a real second use. Avoid general-purpose service layers and helpers that hide ownership.
- Preserve saved data, stable book IDs, verified purchases and atomic rewards. Explain any migration explicitly.
- Use the shared theme and Dynamic Type. Every interactive control must do something useful and have an understandable accessibility label.
- Test meaningful behavior, including failures and retries. Do not claim a core test proves a StoreKit dialog, microphone flow or screen layout works.

Run `scripts/verify.sh` from Terminal for the core suite and project checks. Use Xcode's Cuentiva scheme for iOS tests and manual testing. Apple Intelligence and audio need a supported physical device. Swift 6.2 or newer is required by the package.

The `.swift-format` file defines four-space indentation and a 120-column target. Format the Swift files you change with Xcode's `swift-format`; avoid mixing a repository-wide formatting sweep with behavior changes.

For release work, use [the App Store preparation folder](docs/app-store/README.md). Keep unresolved release decisions visible rather than presenting placeholders as finished configuration.
