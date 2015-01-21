-module(riak_core_xcmd_mgr).

-behavior(supervisor).

-export([
         start_link/0,
         init/1
        ]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).
-define(CHILD(I, Type), ?CHILD(I, Type, 5000)).

%% ===================================================================
%% API functions
%% ===================================================================

-spec start_link() -> pid().
start_link() ->
    {ok, Pid} = supervisor:start_link({local, ?MODULE}, ?MODULE, []),
    riak_core_ring_events:add_sup_callback(fun ring_update/1),
    {ok, Pid}.

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, Ring} = riak_core_ring_manager:get_my_ring(),
    Members = riak_core_ring:all_members(Ring),
    Mods = app_helper:get_env(riak_core, broadcast_mods, [xcmd_manager]),
    BroadcastArgs = [Members, Mods],

    PRoot = application:get_env(riak_core, platform_data_dir, "/tmp"),
    Path = filename:join(PRoot, "cluster_meta"),
    HashtreeArgs = [Path],
    ManagerArgs = [[{data_dir, Path}]],

    Children = [
                ?CHILD(xcmd_manager, worker, ManagerArgs),
                ?CHILD(xcmd_hashtree, worker, HashtreeArgs),
                ?CHILD(xcmd_broadcast, worker, BroadcastArgs)
               ],

    {ok, {{one_for_one, 10, 10}, Children}}.

-spec ring_update(riak_core_ring:riak_core_ring()) -> ok.
ring_update(Ring) ->
    Nodes = riak_core_ring:all_broadcast_members(Ring),
    xcmd_broadcast:membership_update(Nodes).