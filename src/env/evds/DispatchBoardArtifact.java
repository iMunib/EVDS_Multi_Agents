package evds;

import cartago.*;
import java.util.*;

/**
 * DispatchBoardArtifact
 * ----------------------
 * The one shared coordination artifact of the whole MAS. Two independent
 * jobs, both examples of "coordination through the environment" as an
 * alternative to coordination through direct messages or through the
 * organisation:
 *
 *  1. Incident intake -- incident_generator posts new emergencies here;
 *     the event is perceived by the dispatcher, who opens an
 *     organisational scheme for it.
 *
 *  2. Contract-Net bidding -- instead of every responder mailing its bid
 *     straight to "the dispatcher" (which hard-codes a fixed recipient
 *     and does not scale), responders drop bids on this shared board.
 *     collectBids() blocks the *dispatcher's own action* -- using
 *     CArtAgO's await_time primitive, exactly like the BoundedBuffer
 *     example from class -- until the bidding window closes, then
 *     returns the best offer in one call.
 */
public class DispatchBoardArtifact extends Artifact {

    private int counter = 0;
    private final Map<String, List<String>> bidders = new HashMap<>();
    private final Map<String, List<Double>> bidValues = new HashMap<>();
    private final Set<String> openWindows = new HashSet<>();

    void init() {
        defineObsProperty("active_incidents", 0);
    }

    @OPERATION
    public void postIncident(String type, String location, int severity,
                              OpFeedbackParam<String> incidentId) {
        counter++;
        String id = "inc" + counter;
        ObsProperty active = getObsProperty("active_incidents");
        active.updateValue(active.intValue() + 1);
        incidentId.set(id);
        // Perceived once as an event (like the Clock artifact's "tick"),
        // not kept as a standing observable property: the dispatcher acts
        // on it exactly once, when it is reported.
        signal("incident", id, type, location, severity);
    }

    @OPERATION
    public void submitBid(String incId, String vehicleName, double eta) {
        bidders.computeIfAbsent(incId, k -> new ArrayList<>());
        bidValues.computeIfAbsent(incId, k -> new ArrayList<>());
        openWindows.add(incId);

        bidders.get(incId).add(vehicleName);
        bidValues.get(incId).add(eta);
    }

    /**
     * Opens a bidding window for windowMs milliseconds, then blocks
     * (await_time) until it closes, and returns the best (lowest ETA)
     * bidder. This is the artifact-level synchronisation primitive
     * covered in class: the equivalent of BoundedBuffer.get()'s
     * await("itemAvailable"), but time-based instead of guard-based.
     */
    @OPERATION
    public void collectBids(String incId, int windowMs,
                             OpFeedbackParam<String> winner,
                             OpFeedbackParam<Double> winnerEta) {
    	bidders.computeIfAbsent(incId, k -> new ArrayList<>());
    	bidValues.computeIfAbsent(incId, k -> new ArrayList<>());
    	openWindows.add(incId);
        await_time(windowMs);

        openWindows.remove(incId);
        List<String> names = bidders.get(incId);
        List<Double> etas = bidValues.get(incId);
        if (names.isEmpty()) {
            failed("no_bids_received_for_" + incId);
            return;
        }
        int bestIdx = 0;
        for (int i = 1; i < etas.size(); i++) {
            if (etas.get(i) < etas.get(bestIdx)) bestIdx = i;
        }
        winner.set(names.get(bestIdx));
        winnerEta.set(etas.get(bestIdx));
    }

    @OPERATION
    public void closeOutIncident(String incId) {
        ObsProperty active = getObsProperty("active_incidents");
        active.updateValue(Math.max(0, active.intValue() - 1));
        signal("incidentClosed", incId);
    }
}
