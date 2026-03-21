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

These are the available endpoints as of version `0.1.0`.
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
| `version` | The running version, currently `0.1.0` |

### Example
```json
{
	"name": "vs-link-ersatz",
	"version": "0.1.0"
}
```

## `GET` `/sync`
Returns a JSON object with the raw memory blocks containing the player's pokemon data.
See other resources on the generation 4 save format to parse these bytes.

| Field | Description |
| --- | --- |
| `party` | A byte array of length `1416` (`236 * 6`) representing the player's party |
| `pc` | A byte array of length `73440` (`136 * 18 * 30`) representing the player's PC boxes, in order |
| `name` | Always `vs-link-ersatz` |
| `version` | The running version, currently `0.1.0` |

### Example
```json
{
	"party": [12, 13, ...  0, 245],
	"pc": [99, 18, ...  124, 17],
	"name": "vs-link-ersatz",
	"version": "0.1.0"
}
```