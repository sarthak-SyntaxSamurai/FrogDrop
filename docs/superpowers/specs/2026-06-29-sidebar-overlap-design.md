# Design Spec: Sidebar Overlap Fix

This document outlines the design to resolve the layout overlap between the sidebar toggle button and the FrogDrop logo in `MainSidebarView`.

## Context & Problem
In [MainSidebarView.swift](file:///Users/sarthakanand/Projects/new%20app/FrogDrop/Sources/UI/MainSidebarView.swift), the outer `ZStack` does not ignore safe areas, while the inner layout `HStack` does ignore safe areas. Because of this:
- The `HStack` (containing the sidebar) is aligned to the absolute top of the window (Y = 0).
- The outer `ZStack` respects the titlebar safe area inset (~44px on macOS).
- The floating sidebar toggle button inside the `ZStack` is positioned relative to the safe area edge, placing it vertically at Y = 44 + 12 = 56.
- The logo in the sidebar has `.padding(.top, 56)`, placing it at Y = 56 relative to the window top.
- This mismatch causes the toggle button to sit directly on top of the "FrogDrop" logo.

## Proposed Solution (Approach 1)
Apply `.edgesIgnoringSafeArea(.all)` to the outer `ZStack` of `MainSidebarView.swift` rather than just the inner `HStack`. 

This will align the coordinate systems:
- Both elements will start at Y = 0.
- The sidebar toggle button will render at Y = 12 (next to the traffic lights).
- The logo will render at Y = 56 (below the toggle button and traffic lights).

## Verification Plan
1. Compile the app using `swift build`.
2. Run the app using `swift run`.
3. Visually verify that the toggle button no longer overlaps the "FrogDrop" logo.
