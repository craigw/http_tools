-module(http_hammer).
-export([hammer/2, hammer/3]).

statistics(Successes, Errors) ->
  receive
    { From, statistics } ->
      From ! { self(), errors, Errors, successes, Successes },
      statistics(Successes, Errors);
    { _From, success, _Result } ->
      statistics(Successes + 1, Errors);
    { _From, error, _Reason } ->
      statistics(Successes, Errors + 1)
  end.

request(Url, Callback) ->
  case http:request(get, {Url, []}, [{timeout, 5000}], []) of
    { ok, Result } ->
      Callback ! { self(), success, Result };
    { error, Reason } ->
      Callback ! { self(), error, Reason }
  end,
  request(Url, Callback).

spawn_hammer(_Url, 0, _Statistics) -> done;
spawn_hammer(Url, Number, Statistics) ->
  spawn(fun() -> request(Url, Statistics) end),
  spawn_hammer(Url, Number - 1, Statistics).

print_statistics(Statistics, Interval) ->
  receive
  after Interval ->
    Print = fun() ->
      receive
        { Statistics, errors, Errors, successes, Successes } ->
          io:format("Errors: ~p~nSuccesses:~p~n~n", [ Errors, Successes ])
      end
    end,
    Statistics ! { spawn(Print), statistics },
    print_statistics(Statistics, Interval)
  end.

setup() ->
  inets:start().

hammer(Url, Number) -> hammer(Url, Number, infinity).
hammer(Url, Number, Interval) ->
  setup(),
  Statistics = spawn(fun() -> statistics(0, 0) end),
  _Printer = spawn(fun() -> print_statistics(Statistics, Interval) end),
  spawn_hammer(Url, Number, Statistics).
