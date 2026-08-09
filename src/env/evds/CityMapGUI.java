package evds;

import cartago.*;
import cartago.tools.GUIArtifact;

import javax.swing.*;
import java.awt.*;
import java.util.List;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * CityMapGUI
 * -----------
 * Live Swing map for the EVDS project.
 *
 * Vehicle colours:
 *   green  = idle at a station
 *   yellow = en route
 *   red    = on scene
 *
 * Incident markers are red circles with an information label:
 *   inc12 | fire | Sev 3
 *
 * The maps are ConcurrentHashMaps because CArtAgO operations update
 * them from agent threads while Swing paints from the EDT. Vehicle
 * markers sharing a location are displayed as a vertically separated
 * stack so their labels do not overlap.
 */
public class CityMapGUI extends GUIArtifact {

    private MapPanel panel;

    public void setup() {
        JFrame frame = new JFrame("EVDS - City Dispatch Map");
        panel = new MapPanel();

        frame.getContentPane().add(panel);
        frame.setSize(760, 560);
        frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
        frame.setVisible(true);

        defineObsProperty("gui_ready", true);
    }

    /** Called by each responder through common_responder.asl. */
    @OPERATION
    public void vehicleUpdate(String vehId, double x, double y,
                              String status) {
        panel.updateVehicle(vehId, x, y, status);
        panel.repaint();
    }

    /**
     * Called by dispatcher.asl:
     * showIncident(IncId,Type,Sev,LX,LY).
     */
    @OPERATION
    public void showIncident(String incId, String type, int severity,
                             double x, double y) {
        panel.addIncident(incId, type, severity, x, y);
        panel.repaint();
    }

    /** Called after DispatchBoardArtifact closes an incident. */
    @OPERATION
    public void clearIncident(String incId) {
        panel.removeIncident(incId);
        panel.repaint();
    }

    static class MapPanel extends JPanel {

        static class IncidentInfo {
            final String id;
            final String type;
            final int severity;
            final double x;
            final double y;

            IncidentInfo(String id, String type, int severity,
                         double x, double y) {
                this.id = id;
                this.type = type;
                this.severity = severity;
                this.x = x;
                this.y = y;
            }
        }

        private final Map<String, double[]> vehiclePos =
                new ConcurrentHashMap<>();
        private final Map<String, String> vehicleStatus =
                new ConcurrentHashMap<>();
        private final Map<String, IncidentInfo> incidents =
                new ConcurrentHashMap<>();

        void updateVehicle(String id, double x, double y,
                           String status) {
            vehiclePos.put(id, new double[]{x, y});
            vehicleStatus.put(id, status);
        }

        void addIncident(String id, String type, int severity,
                         double x, double y) {
            incidents.put(id, new IncidentInfo(id, type, severity, x, y));
        }

        void removeIncident(String id) {
            incidents.remove(id);
        }

        @Override
        protected void paintComponent(Graphics g) {
            super.paintComponent(g);

            Graphics2D g2 = (Graphics2D) g;
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
                    RenderingHints.VALUE_ANTIALIAS_ON);

            g2.setColor(Color.WHITE);
            g2.fillRect(0, 0, getWidth(), getHeight());

            drawIncidents(g2);
            drawVehicles(g2);
            drawLegend(g2);
        }

        private void drawIncidents(Graphics2D g2) {
            for (IncidentInfo incident : incidents.values()) {
                int x = (int) incident.x;
                int y = (int) incident.y;

                // Red emergency marker.
                g2.setColor(new Color(255, 80, 80));
                g2.fillOval(x - 8, y - 8, 16, 16);

                // Small white backing makes text readable even when a
                // vehicle temporarily passes close to an incident.
                String label = incident.id + " | " + incident.type
                        + " | Sev " + incident.severity;
                FontMetrics metrics = g2.getFontMetrics();
                int width = metrics.stringWidth(label);
                int labelX = x + 12;
                int labelY = y - 14;

                g2.setColor(new Color(255, 255, 255, 220));
                g2.fillRoundRect(labelX - 3, labelY - 13,
                        width + 6, 17, 5, 5);

                g2.setColor(Color.BLACK);
                g2.drawString(label, labelX, labelY);
            }
        }
        
     // Returns true when a vehicle is parked at the same map coordinate
     // as an active incident marker.
	     private boolean hasIncidentAt(double x, double y) {
	         for (IncidentInfo incident : incidents.values()) {
	             if (Math.abs(incident.x - x) < 1.0
	                     && Math.abs(incident.y - y) < 1.0) {
	                 return true;
	             }
	         }
	         return false;
	     }

        private void drawVehicles(Graphics2D g2) {
            // Group vehicles at identical coordinates. This occurs for
            // responders parked at the same station. A stable vertical
            // stack keeps their dots and labels readable.
            Map<String, List<String>> groups = new LinkedHashMap<>();

            for (String id : vehiclePos.keySet()) {
                double[] xy = vehiclePos.get(id);
                if (xy == null) {
                    continue;
                }

                String key = xy[0] + "," + xy[1];
                groups.computeIfAbsent(key, k -> new ArrayList<>()).add(id);
            }

            final int rowHeight = 16;

            for (List<String> group : groups.values()) {
                Collections.sort(group);
                int count = group.size();
                double startYOffset = -((count - 1) * rowHeight) / 2.0;

                for (int i = 0; i < count; i++) {
                    String id = group.get(i);
                    double[] base = vehiclePos.get(id);
                    if (base == null) {
                        continue;
                    }

                    double x = base[0];

	                 // If a vehicle is at an active incident location, move its visual
	                 // marker below the incident circle and its information label.
	                 boolean atIncident = hasIncidentAt(base[0], base[1]);
	                 double incidentOffset = atIncident ? 26 : 0;
	
	                 double y = base[1] + incidentOffset
	                         + startYOffset + i * rowHeight;
                    String status = vehicleStatus.getOrDefault(id, "idle");

                    g2.setColor(colourFor(status));
                    g2.fillOval((int) x - 6, (int) y - 6, 12, 12);

                    g2.setColor(Color.BLACK);
                    g2.drawString(id, (int) x + 10, (int) y + 4);
                }
            }
        }

        private void drawLegend(Graphics2D g2) {
            int x = 16;
            int y = getHeight() - 20;

            g2.setColor(new Color(80, 160, 80));
            g2.fillOval(x, y - 8, 10, 10);
            g2.setColor(Color.BLACK);
            g2.drawString("Idle", x + 14, y + 1);

            x += 75;
            g2.setColor(new Color(230, 180, 40));
            g2.fillOval(x, y - 8, 10, 10);
            g2.setColor(Color.BLACK);
            g2.drawString("En route", x + 14, y + 1);

            x += 105;
            g2.setColor(new Color(200, 40, 40));
            g2.fillOval(x, y - 8, 10, 10);
            g2.setColor(Color.BLACK);
            g2.drawString("On scene / incident", x + 14, y + 1);
        }

        private Color colourFor(String status) {
            switch (status) {
                case "idle":
                    return new Color(80, 160, 80);
                case "en_route":
                    return new Color(230, 180, 40);
                case "on_scene":
                    return new Color(200, 40, 40);
                default:
                    return Color.GRAY;
            }
        }
    }
}