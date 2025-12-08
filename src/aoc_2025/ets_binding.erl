-module(ets_binding).

-export([new_table/1]).

new_table(Name) ->
    try
        {ok, ets:new(Name, [set, private])}
    catch
        error:badarg -> {error, nil}
    end.
