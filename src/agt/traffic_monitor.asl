// traffic_monitor.asl -- a small, purely reactive agent whose only job
// is to keep nudging road congestion so that CityMapArtifact's ETAs
// (and therefore the Contract-Net bids) are not static. Also not part
// of the organisation -- it only touches the environment.

!monitorTraffic.

+!monitorTraffic
   <- .wait(math.random*5000+3000);
      getRandomRoad(A,B);
      Mult = 1.0 + math.random*2.0;
      updateCongestion(A,B,Mult);
      .print("[TRAFFIC] ",A,"<->",B," congestion now x",Mult);
      !monitorTraffic.

{ include("$jacamo/templates/common-cartago.asl") }
