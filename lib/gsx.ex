defmodule Broadcaster do
  @moduledoc """
  Using a GenStage for implementing a GenEvent manager
  replacement where each handler runs as a separate process.
  It is around 40 LOC without docs and comments.
  This implementation will keep events in an internal queue
  until there is demand, leading to client timeouts for slow
  consumers. Alternative implementations could rely on the
  GenStage internal buffer, although such implies events will
  be lost if the buffer gets full (see GenStage docs).
  Generally, the GenStage implementation gives developers
  more control to handle buffers and apply back-pressure while
  leveraging concurrency and synchronization mechanisms.
  """

  use GenStage

  @doc """
  Starts the broadcaster.
  """
  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Sends an event and returns only after the event is dispatched.
  """
  def sync_notify(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  ## Callbacks

  def init(:ok) do
    {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_call({:notify, event}, from, {queue, demand}) do
    dispatch_events(:queue.in({from, event}, queue), demand, [])
  end

  def handle_demand(incoming_demand, {queue, demand}) do
    dispatch_events(queue, incoming_demand + demand, [])
  end

  defp dispatch_events(queue, demand, events) do
    with d when d > 0 <- demand,
         {{:value, {from, event}}, queue} <- :queue.out(queue) do
      GenStage.reply(from, :ok)
      dispatch_events(queue, demand - 1, [event | events])
    else
      _ -> {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end
end

defmodule Consumer do
  @moduledoc """
  The GenEvent handler implementation is a simple consumer.
  """

  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  # Callbacks

  def init(:ok) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.
    {:consumer, :ok, subscribe_to: [Broadcaster]}
  end

  def handle_events(events, _from, state) do
    for event <- events do
      IO.inspect {self(), event}
    end
    {:noreply, [], state}
  end
end

defmodule App do
  @moduledoc """
  Your application entry-point.
  For actual applications, start/0 should be start/2.
  """

  def start do
    import Supervisor.Spec

    children = [
      worker(Broadcaster, []),
      worker(Consumer, [], id: 1),
      worker(Consumer, [], id: 2),
      worker(Consumer, [], id: 3),
      worker(Consumer, [], id: 4)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
