# Smart Nest — SCS 3311 Demo Video Script

## Presenter introduction

Each member states their name, role and the part of the system they implemented.

## Part 1 — Mobile dashboard

- Show the Smart Nest home overview.
- Show current active devices and power usage.
- Open the Floors tab.

## Part 2 — Multi-floor dashboard

- Show Ground Floor and Upper Floor.
- Open a floor.
- Point out the sample floor-plan image and the overlaid room grid.
- Open a room and show its live devices.

## Part 3 — Device control

- Toggle a normal outlet.
- Open a multi-switch unit.
- Toggle two child switches independently.
- Demonstrate ON/OFF/ERROR/DISCONNECTED states.

## Part 4 — Safety and scheduling

- Open the iron.
- Show the maximum ON-duration configuration.
- Turn it on and show the countdown.
- Demonstrate a scheduled light's ON/OFF window.
- Keep the backend worker visible during the cutoff demonstration.

## Part 5 — Security camera

- Open Security Cameras.
- Show the Front Porch mock snapshot.
- Explain that the project uses a mock snapshot because the specification allows mock camera snapshots / URI streams.

## Part 6 — Web hardware simulator

- Show the simulator listening to Firestore.
- Toggle a device in the simulator and show the mobile app update.
- Toggle a device on the mobile app and show the simulator update.
- Simulate a fault and a disconnect.

## Part 7 — Reporting and alerts

- Open Alerts and show backend-generated events.
- Open Reports and show usage data.
- Point out the safety-cutoff event and duration.

## Closing

Summarize the three components: Flutter client, Firebase synchronization/backend worker and web hardware simulator.
