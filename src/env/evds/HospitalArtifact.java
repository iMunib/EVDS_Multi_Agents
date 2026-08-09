package evds;

import cartago.*;

/**
 * HospitalArtifact
 * ------------------
 * A hospital's bed capacity, modelled as a shared resource artifact.
 * Ambulances call admitPatient() directly (found via lookupArtifact,
 * see ambulance.asl) instead of messaging the hospital agent -- a third,
 * deliberately different coordination style alongside the Contract-Net
 * board and the plain agent-to-agent messages used elsewhere, so the
 * project shows all three side by side rather than picking just one.
 *
 * The owning hospital agent (hospital.asl) is still a genuine autonomous
 * agent: it periodically discharges patients on its own initiative,
 * freeing up beds without any request from anyone.
 */
public class HospitalArtifact extends Artifact {

    private int capacity;

    void init(int capacity) {
        this.capacity = capacity;
        defineObsProperty("beds_available", capacity);
    }

    @OPERATION
    public void admitPatient(OpFeedbackParam<Boolean> accepted) {
        ObsProperty beds = getObsProperty("beds_available");
        if (beds.intValue() > 0) {
            beds.updateValue(beds.intValue() - 1);
            accepted.set(true);
        } else {
            accepted.set(false);
        }
    }

    @OPERATION
    public void dischargePatient() {
        ObsProperty beds = getObsProperty("beds_available");
        if (beds.intValue() < capacity) {
            beds.updateValue(beds.intValue() + 1);
        }
    }
}
