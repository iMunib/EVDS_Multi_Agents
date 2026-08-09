package evds;

import cartago.*;
import java.util.*;

/**
 * CityMapArtifact
 * ----------------
 * Environment artifact holding the road-network graph for the city:
 *  - Nodes: stations, hospitals and city landmarks, each with a fixed
 *    (x,y) layout coordinate used only for the Swing visualisation.
 *  - Edges: bidirectional road segments, each with a base travel time
 *    (seconds) and a congestion multiplier that traffic_monitor.asl
 *    mutates at runtime via updateCongestion(), so ETAs genuinely change
 *    during the run.
 *
 * Operations expose shortest-path routing (Dijkstra) so responder agents
 * never reason about the graph themselves. This is deliberate: routing
 * knowledge is *externalised* into the environment, which is the core
 * idea behind the Environment dimension of MAOP -- agents stay simple,
 * the artifact owns the domain-specific competence.
 */
public class CityMapArtifact extends Artifact {

    private final Map<String, double[]> coords = new HashMap<>();
    private final Map<String, Map<String, Double>> baseTime = new HashMap<>();
    private final Map<String, Map<String, Double>> congestion = new HashMap<>();
    private final Random rnd = new Random();

    void init() {
        defineObsProperty("map_ready", false);
        buildGraph();
        getObsProperty("map_ready").updateValue(true);
    }

    private void addNode(String id, double x, double y) {
        coords.put(id, new double[]{x, y});
        baseTime.put(id, new HashMap<String, Double>());
        congestion.put(id, new HashMap<String, Double>());
    }

    private void addRoad(String a, String b, double seconds) {
        baseTime.get(a).put(b, seconds);
        baseTime.get(b).put(a, seconds);
        congestion.get(a).put(b, 1.0);
        congestion.get(b).put(a, 1.0);
    }

    // Layout is intentionally simple (a hand-placed grid) -- swap this for
    // a real map / GIS import without changing any agent code, since
    // agents never see coordinates, only node names.
    private void buildGraph() {
        addNode("Station_North",    80,  60);
        addNode("Station_South",    80, 460);
        addNode("Downtown",        340, 260);
        addNode("Hospital_General",340, 100);
        addNode("Hospital_StMarys",560, 400);
        addNode("University",      200, 160);
        addNode("Mall",            520, 160);
        addNode("Stadium",         620, 260);
        addNode("Bridge",          340, 420);
        addNode("Industrial_Park", 120, 300);
        addNode("Suburb_East",     620,  60);
        addNode("Suburb_West",      20, 260);
        addNode("Highway_Junction",420, 340);
        addNode("Airport",         620, 460);

        addRoad("Station_North","University",40);
        addRoad("University","Downtown",45);
        addRoad("Downtown","Hospital_General",35);
        addRoad("Hospital_General","Mall",50);
        addRoad("Mall","Suburb_East",40);
        addRoad("Mall","Stadium",30);
        addRoad("Downtown","Highway_Junction",40);
        addRoad("Highway_Junction","Bridge",25);
        addRoad("Bridge","Station_South",45);
        addRoad("Bridge","Hospital_StMarys",35);
        addRoad("Hospital_StMarys","Stadium",40);
        addRoad("Hospital_StMarys","Airport",45);
        addRoad("Station_South","Industrial_Park",35);
        addRoad("Industrial_Park","Suburb_West",30);
        addRoad("Suburb_West","Station_North",50);
        addRoad("Downtown","Bridge",50);
        addRoad("Industrial_Park","Downtown",55);
        addRoad("Stadium","Suburb_East",35);
    }
    
    @OPERATION
    public void getNextHop(String from, String to,
                           OpFeedbackParam<String> nextNode) {

        List<String> path = dijkstra(from, to, null);

        if (path == null || path.size() < 2) {
            failed("no_next_hop_" + from + "_" + to);
            return;
        }

        // path[0] is the current node; path[1] is the next node
        // on the lowest-cost route calculated by Dijkstra.
        nextNode.set(path.get(1));
    }

    @OPERATION
    public void getCoords(String node, OpFeedbackParam<Double> x, OpFeedbackParam<Double> y) {
        double[] xy = coords.get(node);
        if (xy == null) { failed("unknown_node_" + node); return; }
        x.set(xy[0]);
        y.set(xy[1]);
    }

    @OPERATION
    public void updateCongestion(String a, String b, double multiplier) {
        if (!congestion.containsKey(a) || !congestion.get(a).containsKey(b)) {
            failed("unknown_road_" + a + "_" + b);
            return;
        }
        congestion.get(a).put(b, multiplier);
        congestion.get(b).put(a, multiplier);
    }

    /** Picks a random existing road, for traffic_monitor.asl -- avoids
     *  duplicating the road list in the agent's own .asl code. */
    @OPERATION
    public void getRandomRoad(OpFeedbackParam<String> a, OpFeedbackParam<String> b) {
        List<String> nodes = new ArrayList<>(coords.keySet());
        for (int tries = 0; tries < 50; tries++) {
            String u = nodes.get(rnd.nextInt(nodes.size()));
            Map<String, Double> nbrs = baseTime.get(u);
            if (!nbrs.isEmpty()) {
                List<String> ns = new ArrayList<>(nbrs.keySet());
                String v = ns.get(rnd.nextInt(ns.size()));
                a.set(u);
                b.set(v);
                return;
            }
        }
        failed("no_roads_found");
    }

    @OPERATION
    public void getRoute(String from, String to, OpFeedbackParam<List<String>> path) {
        List<String> p = dijkstra(from, to, null);
        if (p == null) { failed("no_route_" + from + "_" + to); return; }
        p.remove(0); // drop the origin: the vehicle is already there
        path.set(p);
    }

    @OPERATION
    public void getETA(String from, String to, OpFeedbackParam<Double> etaSeconds) {
        double[] total = new double[1];
        List<String> p = dijkstra(from, to, total);
        if (p == null) { failed("no_route_" + from + "_" + to); return; }
        etaSeconds.set(total[0]);
    }

    /** Standard Dijkstra shortest path weighted by baseTime * congestion. */
    private List<String> dijkstra(String from, String to, double[] outCost) {
        if (!coords.containsKey(from) || !coords.containsKey(to)) return null;

        final Map<String, Double> dist = new HashMap<>();
        Map<String, String> prev = new HashMap<>();
        for (String n : coords.keySet()) dist.put(n, Double.MAX_VALUE);
        dist.put(from, 0.0);

        PriorityQueue<String> pq = new PriorityQueue<>(Comparator.comparingDouble(dist::get));
        pq.add(from);
        Set<String> done = new HashSet<>();

        while (!pq.isEmpty()) {
            String u = pq.poll();
            if (!done.add(u)) continue;
            if (u.equals(to)) break;
            for (Map.Entry<String, Double> e : baseTime.get(u).entrySet()) {
                String v = e.getKey();
                double w = e.getValue() * congestion.get(u).get(v);
                double alt = dist.get(u) + w;
                if (alt < dist.get(v)) {
                    dist.put(v, alt);
                    prev.put(v, u);
                    pq.add(v);
                }
            }
        }
        if (dist.get(to) == Double.MAX_VALUE) return null;

        LinkedList<String> path = new LinkedList<>();
        String cur = to;
        while (cur != null) { path.addFirst(cur); cur = prev.get(cur); }
        if (outCost != null) outCost[0] = dist.get(to);
        return path;
    }
}
