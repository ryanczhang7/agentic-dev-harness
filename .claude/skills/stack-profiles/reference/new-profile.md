# Writing a profile for a new stack

When `/plan-product` chooses an ecosystem the harness has not seen, write a
profile file in this directory before the bootstrap story starts. The bootstrap
story will depend on it, and so will every story after that.

## What a profile must contain

1. **Gate commands**, one line each in `project.conf` format, for every gate the
   ecosystem can support. Non-interactive, non-watching, exit-code-honest.
2. **The coverage story.** Name the tool and how the threshold is enforced. If
   the ecosystem has no coverage tooling, say so explicitly and say what replaces
   it - never leave it implied.
3. **Layout** - where production code, tests and configuration live.
4. **`paths.conf` additions** - the globs that make the phase lock classify this
   stack's files correctly. Get this right or the lock will block the wrong
   writes and the agents will learn to distrust it.
5. **Bootstrap notes** - what the first story must produce, and which step is
   most likely to break.
6. **Testing notes** - the idiomatic runner, the assertion style, how to fake
   time and randomness, and which kinds of test are theatre in this ecosystem.

## Verify before you rely on it

Run every command you write down, in this repository, before the bootstrap story
starts. A profile is documentation of something that works, not a plausible
guess at command-line flags. Versions move, flags get renamed, and an agent with
an empty context will trust this file completely.

## Be honest about weakness

Some ecosystems have poor tooling for some gates. Say so, in the profile, with
the compensating practice - the way `godot.md` handles the absence of coverage
tooling. A profile that quietly omits a gate teaches every future story that the
gate is optional.

## Prerequisites section

Every profile must also carry a **Prerequisites** section: the runtimes and
tools that have to exist on the machine before any gate can run, with install
commands per platform and a verify command for each.

This is the section people actually need and the one most likely to be wrong.
Write the install commands you ran, not the ones the project's website
recommends. Name the executable exactly as `project.conf` will call it -
`scripts/doctor.sh` checks for that name on PATH, and a profile that says
"install Godot" without saying the binary must be callable as `godot` will send
someone hunting for an hour.
