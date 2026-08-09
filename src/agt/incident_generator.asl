// incident_generator.asl -- simulates incoming 911 calls.
// Not part of the organisation: it is a pure environment-facing utility
// agent, not a role-player in the dispatch process itself (a deliberate
// scope decision -- see the report for why not every agent needs to be
// inside the normative organisation).

incident_types(["medical","fire","patrol"]).
locations(["Downtown","Mall","Stadium","University","Airport",
           "Suburb_East","Suburb_West","Industrial_Park","Highway_Junction"]).

!generateIncidents.

+!generateIncidents
   <- .wait(math.random*8000+12000);
      !pickAndPost;
      !generateIncidents.

+!pickAndPost
   <- ?incident_types(Types);
      ?locations(Locs);
      .length(Types,NT);
      N1 = math.floor(math.random*NT);
      .nth(N1,Types,Type);
      .length(Locs,NL);
      N2 = math.floor(math.random*NL);
      .nth(N2,Locs,Loc);
      Sev = math.floor(math.random*5)+1;
      postIncident(Type,Loc,Sev,IncId);
      .print("[911] new ",Type," incident ",IncId," at ",Loc," (severity ",Sev,")").

{ include("$jacamo/templates/common-cartago.asl") }
