# frozen_string_literal: true

# The main suite builds its DB straight from a hand-maintained ActiveRecord::Schema.define
# (spec_helper), so it never exercises the migration files that production actually runs via
# db:prepare. That gap previously hid two real defects (a non-reversible index swap and a lost
# nil-bot_id uniqueness guard). This spec runs the REAL migrations 001–007 in an isolated
# subprocess and asserts the forward end-state, the index guards, and a clean up→down→up.
RSpec.describe "Multi-bot migrations 001–007 (executed, not reproduced)" do
  it "apply forward, guard the right rows, and round-trip without losing the original uniqueness" do
    root = File.expand_path("../..", __dir__)
    script = File.join(__dir__, "apply_and_roundtrip.rb")

    output = `cd #{root} && bundle exec ruby #{script} 2>&1`

    expect($?.exitstatus).to eq(0), "migration check failed:\n#{output}"
    expect(output).to include("MIGRATION_CHECK_OK")
  end
end
