# Batch03 L02 iPhone native review

## Findings

- P1: None in the reviewed L02 states.
- P2: None in the reviewed L02 states.
- P3: None in the reviewed L02 states.

## Scope and evidence

- Source: `55422817203b44ed98a011ccdefb93a2b238243e`; profile: iPhone normal.
- The two L02 methods passed: `testLifeRootRendersAndAddFlowCreatesNewHabit` and `testEditFlowRenamesSeededHabit`.
- The parent SDK archive **failed overall**: 5 executed, 2 passed, 3 failed. L04 and L09 remain failed and outside this native review.
- Reviewed actual PNG and AX for the new/edit hero, focused keyboard, name preview, Fitness icon selection, and both post-Save list states. The 12 selected L02 PNG/AX pairs below were SHA-256 verified against `phone-first-pairs.json`.

## Native observations

- The New Habit hero and Name input remain visible in the initial and keyboard-focused sheet; no visible clipping or overlap.
- Typing “Evening Walk” updates the hero preview; AX exposes the same field value.
- Selecting Fitness changes the hero glyph and highlights its grid tile; AX marks the button Selected.
- The edit sheet shows “Morning Stretch AM” with the keyboard and form controls visible.
- After Save, the Life list shows “Morning Stretch AM” and “Evening Walk”; the selected Fitness glyph appears on the saved card.

## Selected SHA inventory

| # | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---|---|
| 0 | tap habit-form-name | `76514a23563c56cefe145a4980d17c4ef0602e1cdc7c3bf42d82732746ce0f08` | `9122f1f324354c45da01a7fd4c35c3b93df4bd285e136904cb4cdac32ba4e85e` |
| 1 | tap habit-form-name-clear | `b5eb704f4b549713777dd4ebbeaf1c212f67e8ef9233a078d09e5ad85059af39` | `52283d61717b20872c61b827ff88751b0594776a67d32447a9729575abac7c40` |
| 2 | L02 Edit habit name before save | `3034f73b57b7d3e7be9c5188e6b06c63e45ef36efe69f2b55220012996a3ea81` | `3101e63c0bbf1fa2bd2a6a8bbb26fe61d917aeb1a76ad7e356bab87faa1caba3` |
| 3 | tap habit-form-save | `98409ea6d62dd315f927e10487932bf65e4c88b6fdc4f2520e2a9e0a537ef606` | `2b3538adf4fc97a04b853b82524420c85b845ecf765de8e6b0ed33bac2f3672d` |
| 4 | L02 new habit hero | `9131c19deb323d02af4efca9d140278adb31cc27f1494136de53ec47dd5b7bdd` | `c296261607d08bc29329bc1545daba8c0530acb50a08900997f1290625a6edcb` |
| 5 | tap habit-form-name | `00ff6ff8085c07ccf95817c7546d8f572ef495f9eb0002208bab0c219850330f` | `7da7875a4a90e10a090be3c397cd63b3a2847153450655af773cd44bff7e1a6e` |
| 6 | L02 focused habit name and software keyboard | `00ff6ff8085c07ccf95817c7546d8f572ef495f9eb0002208bab0c219850330f` | `25899b4c4faacb06cafbc535e8d4db44a072db6a73be09ef309b87b0cf17d8ce` |
| 7 | tap habit-form-name | `f66be226bea26a319b18ed70c93d3e5f6b08924c2e9f203b1d4801576cc7ad17` | `f88abe64deb51923c30ad2f996b1db050f0a9d8ea55d70ff868f8916a314ca3f` |
| 8 | L02 new habit named preview | `a249e227e5953ac3fe12256af22a125bce49bb5aaca715fd6e6612bf83cd6907` | `ab6a8767b24693437e7b8cc6d322504a62dad6eb4f5181436a69f695dbb689a3` |
| 9 | tap habit-form-icon-fitness | `b9176dc90f519dfd0d25fa5d7dd1b99c5bed6c5c8aafe1abfc9533196bbd2c0f` | `2f492d31c2a181819452547e86117c9e570dc8e0b158458b4c6a77de16af7ce3` |
| 10 | L02 selected icon grid | `b9176dc90f519dfd0d25fa5d7dd1b99c5bed6c5c8aafe1abfc9533196bbd2c0f` | `b625ec70a9951ac5dd67c44e83da44597b622ef43f9cf3b6fb3a68aaa29699a3` |
| 11 | tap habit-form-save | `85819c6dab6a61499f995b1461d460692343d2000e70b226e17fcddd0e6422d0` | `166306920419363f1763d4f06f99f3a001f16b2850bfce826289801723b81414` |

Paths and method names for every selected pair are in the adjacent JSON report.

## Limits

This is a visual and accessibility-tree review of the passed L02 iPhone normal methods. It does not clear the failed L04/L09 methods, the overall phone run, iPad, Duo, closed MAX, or other regressions.
