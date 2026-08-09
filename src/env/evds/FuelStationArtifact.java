package evds;

import cartago.*;

/**
 * FuelStationArtifact
 * ---------------------
 * Small resource-contention example, deliberately mirroring the
 * BoundedBuffer pattern covered in class: a station has a limited
 * number of pumps, and refuel() blocks (await + @GUARD) until one is
 * free. It is off the incident-response critical path -- vehicles top
 * up between calls, in their own background loop -- included to show
 * the await/guard primitive on an artifact whose only job is resource
 * scheduling, separate from DispatchBoardArtifact's time-based
 * await_time() synchronisation.
 */
public class FuelStationArtifact extends Artifact {

    private int freePumps;

    void init(int pumps) {
        this.freePumps = pumps;
        defineObsProperty("free_pumps", pumps);
    }

    @OPERATION
    public void refuel() {
        await("pumpFree");
        freePumps--;
        getObsProperty("free_pumps").updateValue(freePumps);
        await_time(1500); // refuelling takes some time
        freePumps++;
        getObsProperty("free_pumps").updateValue(freePumps);
    }

    @GUARD
    boolean pumpFree() {
        return freePumps > 0;
    }
}
