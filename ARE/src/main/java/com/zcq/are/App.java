package com.zcq.are;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import redis.clients.jedis.Jedis;

import java.io.*;
import java.util.*;

/**
 * Calculate ARE
 */
public class App {

    public static final String SKETCH1 = "sketch1";
    public static final String SKETCH2 = "sketch2";
    public static final String SKETCH3 = "sketch3";
    public static final int MASK = 0xFFFFFFFF;

    public static void main(String[] args) {
        //redis
        Jedis jedis = new Jedis("192.168.1.27", 6379);
        jedis.select(15);

        //dat-hash
        String path = App.class.getClassLoader().getResource("dat-hash.json").getPath();
        HashMap<String, Long> tuples = readJsonFile(path);
        System.out.println("Total flow numbers : " + tuples.size());

        //dat-delay
        path = App.class.getClassLoader().getResource("dat-delay.json").getPath();
        HashMap<String, Double> delay = readDelayJsonFile(path);
//        System.out.println(delay.get("109.86.160.166:20813->1.96.140.4:20480 6"));

        //bloomfilter
        HashMap<Integer, Integer> bloomfilter = bloomfilter(jedis);
        System.out.println("Bloom filter size : " + bloomfilter.size());
//        bloomfilter.entrySet().forEach(entry -> System.out.println(entry.getKey() + " : " + entry.getValue()));

        //sketch
        HashMap<Integer, Pair> sketch1 = parse(jedis.get(SKETCH1), SKETCH1);
        HashMap<Integer, Pair> sketch2 = parse(jedis.get(SKETCH2), SKETCH2);
        HashMap<Integer, Pair> sketch3 = parse(jedis.get(SKETCH3), SKETCH3);
        System.out.println("Sketch size : " + sketch1.size());
        ArrayList<HashMap> hashMaps = new ArrayList<>();
        hashMaps.add(sketch1);
        hashMaps.add(sketch2);
        hashMaps.add(sketch3);

        HashMap<String, Long> temp = new HashMap<>(tuples);

        checkBloomfilter(bloomfilter, temp);
        System.out.println("Total flow number that passes bloomfilter : " + temp.size());
        HashMap<String, Pair> result = querySketch(hashMaps, temp);
        System.out.println("maxIndex : " + maxIndex);
        System.out.println("Total flows that pass bloomfilter and have delay value : " + result.size());
//        for (String s : result.keySet()) {
//            System.out.println(s + " " + result.get(s).toString());
//            System.out.println(delay.get(s));
//        }
        System.out.println("delay和count都取最小值:");
        calculateAre(result, delay);

        HashMap<String, Pair> result2 = querySketch2(hashMaps, temp);
        System.out.println("delay求和，count求和后取平均值:");
        calculateAre(result2, delay);

        HashMap<String, Pair> result3 = querySketch3(hashMaps, temp);
        System.out.println("每个delay和count取平均时延后再取平均值:");
        calculateAre(result3, delay);
    }

    private static int maxIndex = 0;

    private static void calculateAre(HashMap<String, Pair> result, HashMap<String, Double> delay) {
        double sumAre = 0;
        for (String key : result.keySet()) {
            assert delay != null;
            double realDelay = delay.get(key);
            Pair pair = result.get(key);
            double avgDelay = pair.getAvgDelay();
            sumAre += Math.abs(avgDelay - realDelay) / realDelay;
        }
        if (result.size() != 0) {
            double Are = sumAre / result.size();
            System.out.println("Are :" + Are);
        } else {
            System.out.println("No delay data");
        }
    }

    private static HashMap<String, Pair> querySketch3(ArrayList<HashMap> hashMaps, HashMap<String, Long> tuples) {
        HashMap<String, Pair> result = new HashMap<>();
        for (String key : tuples.keySet()) {
            List<Integer> indexes = getIndexes(tuples.get(key), hashMaps.get(0).size());
            double avgDelay = 0;
            long count = Long.MAX_VALUE;
            for (int i = 0; i < 3; i++) {
                int index = indexes.get(i) & MASK;
                maxIndex = Math.max(maxIndex, index);
                Pair pair = (Pair) hashMaps.get(i).get(index);
                count = Math.min(count, pair.getCount());
                if (pair.getCount() != 0) {
                    avgDelay += (double) (pair.getDelay() / pair.getCount());
                }
            }
            if (avgDelay != 0 && count != 0) {
                avgDelay = avgDelay / 3.0;
                result.put(key, new Pair(avgDelay, count));
            } else {
//                System.out.println(key);
            }
        }
        return result;
    }

    private static HashMap<String, Pair> querySketch2(ArrayList<HashMap> hashMaps, HashMap<String, Long> tuples) {
        HashMap<String, Pair> result = new HashMap<>();
        for (String key : tuples.keySet()) {
            List<Integer> indexes = getIndexes(tuples.get(key), hashMaps.get(0).size());
            long delay = 0;
            long count = 0;
            for (int i = 0; i < 3; i++) {
                int index = indexes.get(i) & MASK;
                maxIndex = Math.max(maxIndex, index);
                Pair pair = (Pair) hashMaps.get(i).get(index);
                delay += pair.getDelay();
                count += pair.getCount();
            }
            if (count != 0) {
                double avgDelay = (double) delay / count;
                result.put(key, new Pair(avgDelay, count));
            } else {
//                System.out.println(key);
            }
        }
        return result;
    }

    private static HashMap<String, Pair> querySketch(ArrayList<HashMap> hashMaps, HashMap<String, Long> tuples) {
        HashMap<String, Pair> result = new HashMap<>();
        for (String key : tuples.keySet()) {
            List<Integer> indexes = getIndexes(tuples.get(key), hashMaps.get(0).size());
            long delay = Long.MAX_VALUE;
            long count = Long.MAX_VALUE;
            for (int i = 0; i < 3; i++) {
                int index = indexes.get(i) & MASK;
                maxIndex = Math.max(maxIndex, index);
                Pair pair = (Pair) hashMaps.get(i).get(index);
                delay = Math.min(delay, pair.getDelay());
                count = Math.min(count, pair.getCount());
//                if ("130.77.108.254:13405->1.96.192.77:20480 6".equals(key)) {
//                    System.out.println(pair.getDelay());
//                    System.out.println(pair.getCount());
//                    System.out.println(index);
//                }
            }
            if (count != 0) {
                double avgDelay = (double) delay / count;
                result.put(key, new Pair(avgDelay, count));
            } else {
//                System.out.println(key);
            }
        }
        return result;
    }

    static void checkBloomfilter(HashMap<Integer, Integer> bloomfilter, HashMap<String, Long> tuples) {
        Iterator<Map.Entry<String, Long>> iterator = tuples.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, Long> next = iterator.next();
            List<Integer> indexes = getIndexes(next.getValue(), bloomfilter.size());
            boolean flag = true;
            for (Integer index : indexes) {
                if (bloomfilter.get(index) == 0) {
                    flag = false;
                }
            }
            if (flag) {
                iterator.remove();
            }
        }
    }

    static List<Integer> getIndexes(long hash, int size) {
        String s = Long.toBinaryString(hash);
        while (s.length() < 32) {
            s = "0" + s;
        }
        size = size - 1;
        while ((size & (size - 1)) != 0) {
            size = size & (size - 1);
        }
        size = size << 1;
//        System.out.println("Size : " + size);
        int sz = (int) (Math.log(size) / Math.log(2));
        int index1 = Integer.parseInt(s.substring(32 - sz, 32), 2);
        int index2 = Integer.parseInt(s.substring(24 - sz, 24), 2);
        int index3 = Integer.parseInt(s.substring(16 - sz, 16), 2);
//        if (Long.toBinaryString(hash).equals("111111101010010010000011001010")) {
//            System.out.println(s);
//            System.out.println(s.substring(32 - sz, 32));
//            System.out.println(index2);
//            System.out.println(index3);
//        }
        ArrayList<Integer> indexes = new ArrayList<>();
        indexes.add(index1);
        indexes.add(index2);
        indexes.add(index3);
        return indexes;
    }

    static HashMap<Integer, Integer> bloomfilter(Jedis jedis) {
        HashMap<Integer, Integer> hash = new HashMap<>();
        List<String> candidates = new ArrayList<>();
        candidates.add("bloomfilter1");
        candidates.add("bloomfilter2");
        candidates.add("bloomfilter3");
        for (String candidate : candidates) {
            List<JSONObject> jsonArray = JSON.parseArray(jedis.get(candidate), JSONObject.class);
            for (JSONObject jsonObject : jsonArray) {
                JSONObject keyJson = (JSONObject) jsonObject.get("key");
                int index = Integer.parseInt(keyJson.get("$REGISTER_INDEX").toString());

                JSONObject dataJson = (JSONObject) jsonObject.get("data");
                String key = "Egress.bf_sketch." + candidate + ".f1";
                int flag = JSON.parseArray(dataJson.get(key).toString(), Integer.class).get(1);

                if (hash.get(index) != null && hash.get(index) == 1) {
                    continue;
                } else {
                    hash.put(index, flag);
                }
            }
        }
        return hash;
    }

    static HashMap<Integer, Pair> parse(String str, String key) {
        HashMap<Integer, Pair> hash = new HashMap<Integer, Pair>();
        List<JSONObject> jsonArray = JSON.parseArray(str, JSONObject.class);
        for (JSONObject jsonObject : jsonArray) {
            JSONObject keyJson = (JSONObject) jsonObject.get("key");
            int index = Integer.parseInt(keyJson.get("$REGISTER_INDEX").toString());

            JSONObject dataJson = (JSONObject) jsonObject.get("data");
            String delayKey = "Egress.bf_sketch." + key + ".delay";
            String countKey = "Egress.bf_sketch." + key + ".count";
            long delay = JSON.parseArray(dataJson.get(delayKey).toString(), Long.class).get(1);
            long count = JSON.parseArray(dataJson.get(countKey).toString(), Long.class).get(1);
            hash.put(index, new Pair(delay, count));
        }
        return hash;
    }

    public static HashMap<String, Double> readDelayJsonFile(String fileName) {
        try {
            HashMap<String, Double> hash = new HashMap<>();
            HashMap<String, Pair> temp = new HashMap<>();
            File file = new File(fileName);
            BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
            String line;
            while ((line = reader.readLine()) != null) {
                JSONObject tuples = (JSONObject) JSON.parse(line);
                String key = tuples.get("SrcIP") + ":" + tuples.get("SrcPort") + "->" + tuples.get("DstIP") + ":" + tuples.get("DstPort") + " " + tuples.get("Protocol");
                int value = Integer.parseInt(tuples.get("Delay").toString());
                if (temp.containsKey(key)) {
                    Pair pair = temp.get(key);
                    pair.setDelay(pair.getDelay() + value);
                    pair.setCount(pair.getCount() + 1);
                } else {
                    temp.put(key, new Pair(value, 1));
                }
            }
            for (String key : temp.keySet()) {
                hash.put(key, (double) (temp.get(key).getDelay() / temp.get(key).getCount()));
            }
            return hash;
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

    public static HashMap<String, Long> readJsonFile(String fileName) {
        try {
            HashMap<String, Long> hash = new HashMap<String, Long>();
            File file = new File(fileName);
            BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
            String line;
            int count = 0;
            while ((line = reader.readLine()) != null) {
                count++;
                JSONObject tuples = (JSONObject) JSON.parse(line);
                String key = tuples.get("SrcIP") + ":" + tuples.get("SrcPort") + "->" + tuples.get("DstIP") + ":" + tuples.get("DstPort") + " " + tuples.get("Protocol");
                long value = Long.parseLong(tuples.get("HASH1").toString(), 16);
                hash.put(key, value);
            }
            System.out.println("Total package numbers :" + count);
            return hash;
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

    static class Pair {
        private long delay;
        private long count;

        private double avgDelay;

        public Pair(long delay, long count) {
            this.delay = delay;
            this.count = count;
        }

        public Pair(double avgDelay, long count) {
            this.avgDelay = avgDelay;
            this.count = count;
        }

        public void setDelay(long delay) {
            this.delay = delay;
        }

        public void setCount(long count) {
            this.count = count;
        }

        public void setAvgDelay(double avgDelay) {
            this.avgDelay = avgDelay;
        }

        public long getDelay() {
            return delay;
        }

        public long getCount() {
            return count;
        }

        public double getAvgDelay() {
            return avgDelay;
        }

        @Override
        public String toString() {
            return "Pair{" + "delay=" + delay + ", count=" + count + ", avgDelay=" + avgDelay + '}';
        }
    }
}
