## 2026-08-11 - Web3 Form Accessibility
**Learning:** In Web3 dApps, async blockchain transactions often take a noticeable amount of time, causing users to mistakenly double-click submit buttons if clear feedback isn't provided. Relying solely on a spinner is insufficient for screen readers.
**Action:** Always combine a visual `Loader2` spinner with `disabled={isLoading}` state on the button, and update the `aria-label` dynamically (e.g., `aria-label={isLoading ? "Registering account..." : "Register account"}`) so that screen readers announce the state change during the transaction.
