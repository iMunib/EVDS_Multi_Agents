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
 * CityMapGUI (FIXED v4)
 * ----------------------
 * v3's 3-per-row grid kept the DOTS apart (18px spacing) but text
 * labels are much wider than 18px, so adjacent labels in the same row
 * still smeared together horizontally (confirmed in the v3
 * screenshot: "amb1"+"fire1" merging into unreadable text even though
 * the dots themselves were clearly separated).
 *
 * v4 fix: lay each group out as a single VERTICAL column instead of a
 * grid. Every vehicle in a group gets its own row (dot + its label on
 * that same row, label to the right of the dot); rows are spaced 16px
 * apart vertically, which is enough to clear one line of text height,
 * so no two labels can ever land on the same line and collide.
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

    @OPERATION
    public void vehicleUpdate(String vehId, double x, double y, String status) {
        panel.updateVehicle(vehId, x, y, status);
        panel.repaint();
    }

    @OPERATION
    public void showIncident(String incId, double x, double y) {
        panel.addIncident(incId, x, y);
        panel.repaint();
    }

    @OPERATION
    public void clearIncident(String incId) {
        panel.removeIncident(incId);
        panel.repaint();
    }

    static class MapPanel extends JPanel {
        private final Map<String, double[]> vehiclePos = new ConcurrentHashMap<>();
        private final Map<String, String> vehicleStatus = new ConcurrentHashMap<>();
        private final Map<String, double[]> incidents = new ConcurrentHashMap<>();

        void updateVehicle(String id, double x, double y, String status) {
            vehiclePos.put(id, new double[]{x, y});
            vehicleStatus.put(id, status);
        }

        void addIncident(String id, double x, double y) { incidents.put(id, new double[]{x, y}); }
        void removeIncident(String id) { incidents.remove(id); }

        @Override
        protected void paintComponent(Graphics g) {
            super.paintComponent(g);
            Graphics2D g2 = (Graphics2D) g;
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g2.setColor(Color.WHITE);
            g2.fillRect(0, 0, getWidth(), getHeight());

            g2.setColor(new Color(255, 80, 80));
            for (double[] xy : incidents.values()) {
                g2.fillOval((int) xy[0] - 8, (int) xy[1] - 8, 16, 16);
            }

            Map<String, List<String>> groups = new LinkedHashMap<>();
            for (String id : vehiclePos.keySet()) {
                double[] xy = vehiclePos.get(id);
                if (xy == null) continue;
                String key = xy[0] + "," + xy[1];
                groups.computeIfAbsent(key, k -> new ArrayList<>()).add(id);
            }

            final int ROW_HEIGHT = 16; // enough to clear one line of text vertically

            for (List<String> group : groups.values()) {
                Collections.sort(group); // stable order across repaints
                int n = group.size();
                // Centre the column of rows around the base y so a
                // single vehicle still sits exactly on its station point.
                double startYOffset = -((n - 1) * ROW_HEIGHT) / 2.0;

                for (int i = 0; i < n; i++) {
                    String id = group.get(i);
                    double[] base = vehiclePos.get(id);
                    if (base == null) continue;

                    double x = base[0];
                    double y = base[1] + startYOffset + i * ROW_HEIGHT;

                    String status = vehicleStatus.getOrDefault(id, "idle");
                    g2.setColor(colourFor(status));
                    g2.fillOval((int) x - 6, (int) y - 6, 12, 12);
                    g2.setColor(Color.BLACK);
                    g2.drawString(id, (int) x + 10, (int) y + 4);
                }
            }
        }

        private Color colourFor(String status) {
            switch (status) {
                case "idle": return new Color(80, 160, 80);
                case "en_route": return new Color(230, 180, 40);
                case "on_scene": return new Color(200, 40, 40);
                default: return Color.GRAY;
            }
        }
    }
}