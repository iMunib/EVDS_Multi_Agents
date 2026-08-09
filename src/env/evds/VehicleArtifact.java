package evds;

import cartago.*;

/**
 * VehicleArtifact
 * ----------------
 * Physical/observable state of a single responder vehicle: name,
 * position and status. Every agent creates its own instance in its
 * setup plan (see common_responder.asl: +!setupVehicle) and focuses it,
 * so status/position changes are perceived as ordinary beliefs by the
 * owning agent (and, using namespace-prefixed focus, by supervisor1
 * during the decentralised fallback -- see supervisor.asl).
 *
 * Every updatePosition() call also signals the "vehicleUpdate" output
 * port. In each vehicle's setup plan this port is linked directly to
 * CityMapGUI with linkArtifacts(vehId, "vehicleUpdate", mapViewId): the
 * map view is kept in sync purely through this artifact-to-artifact
 * link, with no extra agent messages or polling involved.
 */
public class VehicleArtifact extends Artifact {

    void init(String name, double x, double y) {
        defineObsProperty("vname", name);
        defineObsProperty("posX", x);
        defineObsProperty("posY", y);
        defineObsProperty("status", "idle");
    }

    @OPERATION
    public void updatePosition(double x, double y, String status) {
        System.err.println("[DEBUG] VehicleArtifact.updatePosition called: " + x + "," + y + " " + status);
        getObsProperty("posX").updateValue(x);
        getObsProperty("posY").updateValue(y);
        getObsProperty("status").updateValue(status);
        signal("vehicleUpdate", getObsProperty("vname").stringValue(), x, y, status);
    }

    @OPERATION
    public void setStatus(String status) {
        getObsProperty("status").updateValue(status);
        signal("vehicleUpdate",
               getObsProperty("vname").stringValue(),
               getObsProperty("posX").doubleValue(),
               getObsProperty("posY").doubleValue(),
               status);
    }
}
