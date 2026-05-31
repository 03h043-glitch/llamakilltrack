# LlamaToLevel

LlamaToLevel is a lightweight WoW Classic addon that estimates how many kills and quests it should take to reach your next level.

## How It Calculates

- Kills are estimated from the average XP of your last five XP-granting kills this session.
- If you have fewer than five kills this session, it uses the kills available so far.
- Quests are estimated separately from quest/non-kill XP gains so quest turn-ins do not inflate the kill estimate.

## Install

Copy the `LlamaToLevel` folder into:

```text
World of Warcraft\_classic_\Interface\AddOns\
```

For Classic Era, the folder may be:

```text
World of Warcraft\_classic_era_\Interface\AddOns\
```

Restart the game or run `/reload`.

## Use

- Kill something that grants XP.
- A floating message appears near the top of the screen.
- The small on-screen tracker shows `x kills / x quests`.
- Left-drag the tracker to move it.
- Right-click the tracker, or type `/llt`, to open settings.

## Commands

```text
/llt                Toggle settings
/llamatolevel       Toggle settings
/llt test           Show a test floating message
/llt reset          Reset tracker position, size, colour, and opacity
```
