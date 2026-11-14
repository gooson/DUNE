---
title: P08 posture comparison on Phone, iPad, and Duo
date: 2026-11-14
status: source and native verification complete; publication rebase pending
---

# P08 posture comparison

The comparison view keeps the older and newer scores, score difference, dates, two independent scroll panes, and Front photo zoom with Close return. A source change places Capture and Compare/Cancel in an explicit More menu on Posture History; the notification route still reaches Capture through that menu.

The Open Duo normal retry passed at ce7be698 and showed scores 73, 86, +13; Oct 31 and Nov 13; Front zoom and Close; and the lower metric pane. Open Duo MAX passed on source 6323abf8. Phone/iPad normal and MAX evidence has byte-identical P08 app files but earlier test sources. Closed Duo MAX passed at ce7be698. Closed Duo normal passed at 73d705e after a native Toolbar Close query correction. Both original Closed failures, the Open normal failure, and the first Closed Close failure remain in the failure ledger. The previous failures and the 2026-11-06 review tree remain preserved.

The per-screen PR still requires a current-main rebase and publication review. This record does not claim a full regression run.
