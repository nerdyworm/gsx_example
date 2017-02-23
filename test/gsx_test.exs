defmodule GsxTest do
  use ExUnit.Case

  test "the truth" do
    # Start the app
    App.start

    # Broadcast events
    Broadcaster.sync_notify(1)

    Broadcaster.sync_notify(2)
    Broadcaster.sync_notify(3)
    Broadcaster.sync_notify(4)
    Broadcaster.sync_notify(5)

    # DONT Wait for them to be printed
    #
    # There should be a way to ensure that all work is completed
    # without sleeping
    # Process.sleep(2000)
  end
end
