# Security

Powerbar runs inside the Omarchy shell as you: no daemon, no root, no network
connections. README.md, "What Powerbar touches", lists every file it reads or
writes and every command it runs.

## Reporting a problem

Report a vulnerability privately through GitHub: the repository's
**Security** tab, **Report a vulnerability**
(<https://github.com/overp0werj0int/powerbar/security/advisories/new>).
Please don't open a public issue for it. Include the Powerbar version
(`omarchy-shell powerbar build`), your Omarchy version, and the steps that
show the problem.

A fix ships as a new release with a CHANGELOG entry that credits you, unless
you'd rather not be named.

## Supported versions

Only the latest release gets fixes.
