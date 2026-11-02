# Specs

This project uses `kettle-test` as its RSpec harness. The generated
`spec/spec_helper.rb` requires `kettle/test/rspec`, which installs the shared
test configuration and helper APIs used throughout the suite.

## Harness Helpers

These helpers are available in specs after `spec/spec_helper.rb` loads:

- `stub_env("NAME" => "value")` temporarily sets environment variables and
  restores them after the example.
- `hide_env("NAME")` temporarily removes environment variables and restores
  them after the example.
- `block_is_expected` supports expectation syntax for blocks.
- `:check_output` disables default stream silencing for examples that need to
  assert output.
- `:freeze` and `:travel` metadata integrate with Timecop for example-level
  time control.
- `:skip_global_travel` opts an example out of global time travel.
- `pending_for` marks examples pending for selected runtimes or dependency
  versions.
- `include_context "with rake", "task_name"` is available when `rake` was
  loaded before `kettle/test/rspec`.

Prefer these helpers over ad hoc ENV mutation, direct Timecop setup, or direct
stdout/stderr plumbing. They keep specs isolated across parallel workers and
make local runs match CI behavior.

## Running the suite

The suite needs GTK, Libadwaita and a display, which the flake's devshell
carries:

```sh
nix develop --command xvfb-run -a \
  ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

That shell carries the gemspec's runtime dependencies plus RSpec, not the
root Gemfile's development bundle, so `kettle/test/rspec` is absent there.
`spec/spec_helper.rb` therefore requires it the way it requires
`kettle-soup-cover`: when it is missing the suite runs without the harness
helpers above, and `bundle exec rspec` from the root Gemfile still gets them.

## Driving the app

The specs assert; `test/drive_main_window.rb` runs the real application,
takes it through loading, shredding, aborting and the exit dialog, and writes
a screenshot of each state to `tmp/shots`:

```sh
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
```

It exits non-zero if any of its checks fail, so it works as a test command.
