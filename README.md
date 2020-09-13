# Alliedmods
https://forums.alliedmods.net/showthread.php?t=327026

# multiple_center_texts_and_hints
Display multiple center texts and hints at once through channels.
For games where hints texts are not displayed in the same place as center texts. Example: Counter-Strike Source.

## Usage:
There are 16 channels available for CenterText and 16 channels for HintText.
```
PrintCenterText(client, "{1}center 1");
PrintCenterText(client, "{2}center 2");

PrintHintText(client, "{1}hint 1");
PrintHintText(client, "{2}hint 2");
```

## ConVars
```
sm_center_text_channel_duration 5.0
sm_channel_text_channel_duration 5.0
```

# multiple_center_texts
Display multiple center texts at once through channels. Hint texts will become center texts.
For games where hints texts are displayed in the same place as center texts. Example: Counter-Strike Global Offensive.


## Usage:
There are 16 channels available for CenterText and HintText.
```
PrintCenterText(client, "{1}center 1");
PrintCenterText(client, "{2}center 2");

PrintHintText(client, "{1}hint 1"); // this will become CenterText and will replace "center 1" message
PrintHintText(client, "{2}hint 2");
```

## ConVars
```
sm_center_text_channel_duration 5.0
```
