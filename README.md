# Vs. Link Ersatz
Vs. Link Ersatz is a (hopefully temporary) Lua script for DeSmuME for Platinum Kaizo that can communicate with web applications through an HTTP API.

## Usage
Make sure you've installed `lua51.dll` next to your DeSmuME executable.
This is required to run any Lua script.

You can grab a download at the [latest release](https://github.com/emilyploszaj/vs-link-ersatz/releases/latest).
Unzip the `vs-link-ersatz.zip` into a folder.
Open DeSmuME's scripting window and open `vs-link-ersatz.lua`.


For some reason, when a Lua script is loaded in DeSmuME, the hold and toggle speedup buttons lag the game intensely.
Even an empty script with a frame callback will cause this, so, unfortunately, you will need to use the "increase speed" and "decrease speed" binds (`+` and `-` by default) instead.

### Building
Building the dll itself is going to be a nightmare, I use Linux and cross compile it.
If you also use Linux, use the `build.sh`, you will need D and Windows `.lib` flies in `libs/`.
You can get these from D releases.
If you're on some other architecture I'm sorry.
It's probably not that hard to build on Windows, but I have no clue.

I'd accept a PR to get this building on Mac.
Unfortunately, the current version only supports Windows and Unix through Wine, and I don't have an Apple computer to develop on.

## API
For developers of other web applications, here's a poor description of the HTTP API.

Vs. Link Ersatz is hosted on port `31123`, and can be accessed from web browsers through `localhost:31123`.

## Endpoints

These are the available endpoints as of version `0.2.0`.
More are planned.

If a malformed request is received by Vs. Link Ersatz, it will return a JSON object with a description of the error.

### Example
Here's an example error returned by `GET` `/fake/path`
```json
{
	"error": "Unknown Vs. Link Ersatz command"
}
```

## `GET` `/ping`
Returns a JSON object describing the status of Vs. Link Ersatz

| Field | Description |
| --- | --- |
| `name` | Always `vs-link-ersatz` |
| `version` | The running version, currently `0.2.0` |

### Example Response
```json
{
	"name": "vs-link-ersatz",
	"version": "0.2.0"
}
```

## `GET` `/sync`
Returns a JSON object with the raw memory blocks containing the player's pokemon data.
See other resources on the generation 4 save format to parse these bytes.

### Response
| Field | Description |
| --- | --- |
| `party` | A byte array of length `1416` (`236 * 6`) representing the player's party |
| `pc` | A byte array of length `73440` (`136 * 18 * 30`) representing the player's PC boxes, in order |
| `name` | Always `vs-link-ersatz` |
| `version` | The running version, currently `0.2.0` |

### Example Response
```json
{
	"party": [12, 13, ...  0, 245],
	"pc": [99, 18, ...  124, 17],
	"name": "vs-link-ersatz",
	"version": "0.2.0"
}
```

## `POST` `/status`

Inflicts status effects on certain party members. While the request is restricted to statuses the player could reasonably obtain, there's no thorough way to determine based on the current game state what statuses are valid. For instance, in a gauntlet without encounters, it would not be reasonable to become poisoned between battles, but Vs. Link Ersatz would be able to inflict this status. In contrast, a player is never able to inflict a certain number of sleep turns outside of 0 in normal gameplay while knowing they've done so, which is why Vs. Link Ersatz does not enable this functionality.

### Request

| Field | Description |
| --- | --- |
| `statuses` | An array of JSON objects |
| `statuses[n].index` | An integer for which party member should be statused. From `0` to `5` |
| `statuses[n].status` | What status to inflict to this party member. One of `"slp"`, `"psn"`, `"brn"`, `"frz"`, `"prz"`, or `"tox"`. Any other value will clear the status. `"slp"` will always afflict 0 turn sleep. |

### Example Request

The following request would afflict the first member of the party with poisoning and the 5th member of the party with sleep.
```json
{
	"statuses": [
		{
			"index": 0,
			"status": "psn"
		},
		{
			"index": 4,
			"status": "slp"
		}
	]
}
```

### Response
See `GET` `/ping`.

## `PUT` `/time`

Sets the in game time. Currently only supports setting the current hour. The values will not change on their own, that is, the hour will not roll over when the minutes do.

### Request

| Field | Description |
| --- | --- |
| `time` | A JSON object |
| `time.hour` | The hour to pin to in the range `[0..23]` |

### Example Request

The following request would pin the clock's hour to 14:xx (2:xx PM).
```json
{
	"time": {
		"hour": 14
	}
}
```

### Response
See `GET` `/ping`.

## `DELETE` `/time`

Resets all changes to in game time and returns to matching the device's clock, the default behavior of DeSmuME.

### Response
See `GET` `/ping`.