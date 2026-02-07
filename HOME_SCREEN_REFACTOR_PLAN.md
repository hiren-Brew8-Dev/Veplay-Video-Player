# Home Screen Refactor Plan

This plan outlines the steps to refactor the Home Screen and related components as per the user's request.

## Phase 1: Video Section & List UI
- [x] **1. Video Cell UI Refinement**
    - [x] Update time and size to be on the same vertical lines (separated by HStack).
    - [x] Utilize the space between 3-dots and MB size by reducing trailing gap.
    - [x] Ensure proper alignment of the context menu.
- [x] **2. Context Menu Update**
    - [x] Update global context menu order:
        1. Select
        --- (Divider)
        2. Grid
        3. List
        --- (Divider)
        4. Sort
- [x] **3. 3-Dots Alignment**
    - [x] Align the list view video card's 3-dots button with the navbar's 3-dots button (exactly 16pt trailing).

## Phase 2: Home Screen Sheet & Animation
- [x] **4. Sheet Animation**
    - [x] Implement bottom-to-top transition for sheets.
    - [x] Separate the color code of the sheet (`sheetBackground`) from the Home Screen background.

## Phase 3: Bottom "+" Button & Tab Bar Logic
- [x] **5. Dynamic "+" Button Logic**
    - [x] **Video Section**: Hide "Create Folder" from context menu.
    - [x] **Folder Section**: Show ONLY "Create Folder".
    - [x] **Gallery Tab**: Hide the "+" icon completely.
    - [x] **Search Section**: Hide Bottom Tabbar & Plus icon.
- [x] **6. Button & Shadow Isolation**
    - [x] Separate the "+" button and its shadow into a ZStack.

## Phase 4: Header & Search Consistency
- [x] **7. Header UI Consistency**
    - [x] Standardized Search & 3-dots (Size 20, Semibold, Blue, 12pt spacing) across Home and Folder Details.

## Phase 5: Folder Operations
- [x] **8. Delete Folder Alert**
    - [x] Show confirmation alert when deleting a folder.

## Phase 6: Settings & Theming
- [x] **9. Settings Cleanup**
    - [x] Removed "Auto play next video" switch.
- [x] **10. Centralized Color System**
    - [x] Created `homeBackground`, `homeCardBackground`, `sheetBackground`, etc., in `Colors.swift`.
    - [x] Applied to all Home Screen components for consistent theming.

## Execution Summary
All requirements have been met and verified across `HomeView`, `DashboardView`, `VideoSectionView`, `FolderSectionView`, `SearchView`, and various component views.
