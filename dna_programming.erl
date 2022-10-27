%% NB: You can find the original code we used for message passing in
%% https://www.erlang.org/doc/getting_started/conc_prog.html

-module(dna_programming).
-import(lists,[append/2]).
-record(dna, {id, age, type, genome = [], networkTopology=[], linksToParents=[], linksToChildren=[]}).
-export([start/1, start_server/0, server/1, logon/1, logoff/0, message/2, client/2, creat_dna/7,
  start_ping/2, start_pong/0, fork/2, to_fork_on/1, update_genome/2]).

%%% Change the function below to return the name of the node where the
%%% messenger server runs
server_node() ->
  messenger@super.

%%% This is the server process for the "messenger"
%%% the user list has the format [{ClientPid1, Name1},{ClientPid22, Name2},...]
server(User_List) ->
  receive
    {From, logon, Name} ->
      New_User_List = server_logon(From, Name, User_List),
      server(New_User_List);
    {From, logoff} ->
      New_User_List = server_logoff(From, User_List),
      server(New_User_List);
    {From, message_to, To, Message} ->
      server_transfer(From, To, Message, User_List),
      io:format("list is now: ~p~n", [User_List]),
      server(User_List)
  end.

%%% Start the server
start_server() ->
  register(messenger, spawn(messenger, server, [[]])).


%%% Server adds a new user to the user list
server_logon(From, Name, User_List) ->
  %% check if logged on anywhere else
  case lists:keymember(Name, 2, User_List) of
    true ->
      From ! {messenger, stop, user_exists_at_other_node},  %reject logon
      User_List;
    false ->
      From ! {messenger, logged_on},
      [{From, Name} | User_List]        %add user to the list
  end.

%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
  lists:keydelete(From, 1, User_List).


%%% Server transfers a message between user
server_transfer(From, To, Message, User_List) ->
  %% check that the user is logged on and who he is
  case lists:keysearch(From, 1, User_List) of
    false ->
      From ! {messenger, stop, you_are_not_logged_on};
    {value, {From, Name}} ->
      server_transfer(From, Name, To, Message, User_List)
  end.
%%% If the user exists, send the message
server_transfer(From, Name, To, Message, User_List) ->
  %% Find the receiver and send the message
  case lists:keysearch(To, 2, User_List) of
    false ->
      From ! {messenger, receiver_not_found};
    {value, {ToPid, To}} ->
      ToPid ! {message_from, Name, Message},
      From ! {messenger, sent}
  end.


%%% User Commands
logon(Name) ->
  case whereis(mess_client) of
    undefined ->
      register(mess_client,
        spawn(messenger, client, [server_node(), Name]));
    _ -> already_logged_on
  end.

logoff() ->
  mess_client ! logoff.

message(ToName, Message) ->
  case whereis(mess_client) of % Test if the client is running
    undefined ->
      not_logged_on;
    _ -> mess_client ! {message_to, ToName, Message},
      ok
  end.


%%% The client process which runs on each server node
client(Server_Node, Name) ->
  {messenger, Server_Node} ! {self(), logon, Name},
  await_result(),
  client(Server_Node).

client(Server_Node) ->
  receive
    logoff ->
      {messenger, Server_Node} ! {self(), logoff},
      exit(normal);
    {message_to, ToName, Message} ->
      {messenger, Server_Node} ! {self(), message_to, ToName, Message},
      await_result();
    {message_from, FromName, Message} ->
      io:format("Message from ~p: ~p~n", [FromName, Message])
  end,
  client(Server_Node).

%%% wait for a response from the server
await_result() ->
  receive
    {messenger, stop, Why} -> % Stop the client
      io:format("~p~n", [Why]),
      exit(normal);
    {messenger, What} ->  % Normal response
      io:format("~p~n", [What])
  end.

fork(0, ToForkOnNode) ->
  {pong, ToForkOnNode} ! finished,
  io:format("Finished forking ~n", []);

fork(N, ToForkOnNode) ->
  {pong, ToForkOnNode} ! {ping, self()},
  receive
    pong ->
      io:format("", [])
  end,
  fork(N, ToForkOnNode).

to_fork_on(DNA) ->
  receive
    finished ->
      dna = creat_dna(DNA#dna.id, DNA#dna.age, DNA#dna.type,
        DNA#dna.genome, DNA#dna.networkTopology, DNA#dna.linksToParents, DNA#dna.linksToChildren);
    {ping, Ping_PID} ->
      Ping_PID ! pong,
      to_fork_on(DNA)
  end,
  start(dna).

start_pong() ->
  register(pong, spawn(tut17, pong, [])).

start_ping(Pong_Node, DNA) ->
  spawn(messagePassing, ping, [Pong_Node, DNA]).

%% LinksToParents : A list of names (in general IPs) of the parents. Since we add the parents to the lists in a
%% stack manner, the first item is thus the root of the network
%% LinksToChildren: A list of all forks that the agent performs

update_genome(DNA, List_Genomes)->
  l = append(DNA#dna.genome, List_Genomes),
  DNA_modified = DNA#dna{genome =  List_Genomes},
  DNA_modified.



creat_dna(Id, Age, Type, Genome, NetworkTopology, LinksToParents, LinksToChildren) ->
  DNA = #dna{id = Id,age = Age, genome = Genome, type = Type, networkTopology = NetworkTopology,
    linksToParents = LinksToParents, linksToChildren = LinksToChildren},
  DNA.

start(DNA)->
  io:format("Agent started...~p~n", [DNA#dna.id]).