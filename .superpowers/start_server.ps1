$env:BRAINSTORM_DIR = "d:\projet\lmplot\.superpowers\brainstorm\session-001"
$env:BRAINSTORM_HOST = "127.0.0.1"
$env:BRAINSTORM_URL_HOST = "localhost"
$env:BRAINSTORM_OWNER_PID = "1"

if (!(Test-Path $env:BRAINSTORM_DIR)) {
    New-Item -ItemType Directory -Force -Path "$env:BRAINSTORM_DIR\content", "$env:BRAINSTORM_DIR\state"
}

node "C:\Users\ktubi\.gemini\antigravity\skills\brainstorming\scripts\server.cjs"
