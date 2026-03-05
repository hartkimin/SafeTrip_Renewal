# UI Mockup Generation Execution Plan (Batch Processing by Domain)

## Goal
Generate UI mockups based on the `docs\wireframes` directory containing 16 markdown specificitations (1 Style Guide + 15 feature files). To avoid context overflow and assure consistency with `00_Global_Style_Guide.md`, we will process these using Stitch MCP in functional domain batches.

## Assumptions
- Stitch MCP (using the Pencil server capabilities) will correctly map Markdown structure (elements structured with lines and # tags) into UI components.
- Providing `00_Global_Style_Guide.md` in every prompt will enforce visual consistency.
- Generated results will be persisted as `.pen` files or similar supported outputs within Pencil/Stitch context, ideally creating a dedicated canvas per batch.

## Plan

1. **Batch 1: Core Base & Auth/Profiles**
   - Files: `docs/wireframes/00_Global_Style_Guide.md`, `docs/wireframes/A_Onboarding_Auth.md`, `docs/wireframes/K_Settings_Profile.md`
   - Change: Build foundation components using the style guide. Generate the Onboarding, Authentication, and Settings/Profile mockups. Create `Core_Auth.pen`.
   - Verify: Check successful visual creation and element fidelity against markdown schemas using the `pencil` tools (e.g. `batch_get` or checking artifact output).

2. **Batch 2: Locations & Core Mapping**
   - Files: `docs/wireframes/00_Global_Style_Guide.md`, `docs/wireframes/B_Trip_Creation.md`, `docs/wireframes/C_MainMap_CommonUI.md`, `docs/wireframes/E_Location_Privacy.md`
   - Change: Generate map-heavy UIs, location tracking permissions, and the trip creation flows. Create `Map_Tracking.pen`.
   - Verify: Check components handle map-placeholders, floating UI overlays, and trip card layouts properly.

3. **Batch 3: Guarding, Minors & Attendance**
   - Files: `docs/wireframes/00_Global_Style_Guide.md`, `docs/wireframes/F_Guardian_System.md`, `docs/wireframes/H_Attendance.md`, `docs/wireframes/M_Minor_Protection.md`
   - Change: Generate complex user-management UIs linking adults with minors, and check-in/attendance flows. Create `Guardianship.pen`.
   - Verify: Examine guardian connection UI, check-in button states, and special protections for minors.

4. **Batch 4: Trip Management, SOS & Guides**
   - Files: `docs/wireframes/00_Global_Style_Guide.md`, `docs/wireframes/D_Trip_Management.md`, `docs/wireframes/G_SOS_Emergency.md`, `docs/wireframes/J_Safety_Guide.md`
   - Change: Construct timeline/itinerary screens, the red emergency/SOS overlays, and dynamic travel safety information lists. Create `Emergency_Guides.pen`.
   - Verify: Check emergency UI visibility contrast, scrolling itineraries, and safe-guide card consistency.

5. **Batch 5: Auxiliary Domains & Payments**
   - Files: `docs/wireframes/00_Global_Style_Guide.md`, `docs/wireframes/I_Chat_Communication.md`, `docs/wireframes/L_Payment_Subscription.md`, `docs/wireframes/N_B2B_Portal.md`, `docs/wireframes/O_AI_Features.md`
   - Change: Produce mockups for the chat interface, payment gateways, specific B2B screens, and AI itinerary planner visual components. Create `Aux_Features.pen`.
   - Verify: Ensure chat bubbles, payment tiers, portal boundaries, and AI chat/suggestions show as designed.

## Risks & mitigations
- **Risk**: Stitch MCP fails to process large context or misses details.
  - **Mitigation**: If a batch fails or generates low-quality output, subdivide the batch further (e.g., separating `K_Settings_Profile.md` from Batch 1) and retry.
- **Risk**: Style inconsistencies across different `.pen` files.
  - **Mitigation**: The explicit inclusion of `00_Global_Style_Guide.md` in *every* batch is designed to prevent this. We will review the first batch carefully to ensure the style guide is being respected before proceeding with others.

## Rollback plan
- If the generated mockups are incorrect or broken:
  1. Delete the generated `.pen` files.
  2. Refine the prompt to Stitch MCP to better explain the markdown structure.
  3. Restart the generation with the revised prompt.
