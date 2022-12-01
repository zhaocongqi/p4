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
    public static final String COUNT1 = "count1";
    public static final String COUNT2 = "count2";
    public static final String COUNT3 = "count3";
    public static final int MASK = 0x0001FFFF;

    public static void main(String[] args) {
        //redis
        Jedis jedis = new Jedis("192.168.1.27", 6379);
        jedis.select(15);

        //dat-hash
        String path = App.class.getClassLoader().getResource("dat-hash.json").getPath();
        HashMap<String, Tuples> tuples = readJsonFile(path);
        System.out.println("Total flow numbers : " + tuples.size());

        //dat-delay
        path = App.class.getClassLoader().getResource("dat-delay.json").getPath();
        HashMap<String, Pair> data = readDelayJsonFile(path);
//        System.out.println(data.get("111.37.249.98:30817->1.8.158.123:20480 6"));

        //bloomfilter
        HashMap<Integer, Integer> bloomfilter = bloomfilter(jedis);
        System.out.println("Bloom filter size : " + bloomfilter.size());
//        bloomfilter.entrySet().forEach(entry -> System.out.println(entry.getKey() + " : " + entry.getValue()));

        //sketch
        HashMap<Integer, Pair> sketch1 = parse(jedis.get(SKETCH1), jedis.get(COUNT1), SKETCH1, COUNT1);
        HashMap<Integer, Pair> sketch2 = parse(jedis.get(SKETCH2), jedis.get(COUNT2), SKETCH2, COUNT2);
        HashMap<Integer, Pair> sketch3 = parse(jedis.get(SKETCH3), jedis.get(COUNT3), SKETCH3, COUNT3);
        System.out.println("Sketch size : " + sketch1.size());
        ArrayList<HashMap> hashMaps = new ArrayList<>();
        hashMaps.add(sketch1);
        hashMaps.add(sketch2);
        hashMaps.add(sketch3);

        HashMap<String, Tuples> temp = new HashMap<>(tuples);
        checkBloomfilter(bloomfilter, temp);
        System.out.println("Total flow number that passes bloomfilter : " + temp.size());

        HashMap<String, Pair> result = querySketch(hashMaps, temp);
        System.out.println("maxIndex : " + maxIndex);
        System.out.println("Total flows that pass bloomfilter and have delay value : " + result.size());
//        for (String s : result.keySet()) {
//            System.out.println(s + " " + result.get(s).toString());
//            System.out.println(data.get(s));
//        }
        calculateAre(result, data);
    }

    private static int maxIndex = 0;

    private static void calculateAre(HashMap<String, Pair> testData, HashMap<String, Pair> realData) {
        double sumDelayAre = 0;
        double sumCountAre = 0;
        double sumAvgDelayAre = 0;
        for (String key : testData.keySet()) {
            Pair testPair = testData.get(key);
            Pair realPair = realData.get(key);
            sumDelayAre += (double) Math.abs(testPair.getDelay() - realPair.getDelay()) / realPair.getDelay();
            sumCountAre += (double) Math.abs(testPair.getCount() - realPair.getCount()) / realPair.getCount();
            sumAvgDelayAre += (double) Math.abs(testPair.getAvgDelay() - realPair.getAvgDelay()) / realPair.getAvgDelay();
        }
        if (testData.size() != 0) {
            sumDelayAre = sumDelayAre / testData.size();
            sumCountAre = sumCountAre / testData.size();
            sumAvgDelayAre = sumAvgDelayAre / testData.size();
            System.out.println("sumDelayAre :" + sumDelayAre);
            System.out.println("sumCountAre :" + sumCountAre);
            System.out.println("sumAvgDelayAre :" + sumAvgDelayAre);
        } else {
            System.out.println("No data");
        }
    }

    private static HashMap<String, Pair> querySketch(ArrayList<HashMap> hashMaps, HashMap<String, Tuples> tuples) {
        HashMap<String, Pair> result = new HashMap<>();
        for (String key : tuples.keySet()) {
            List<Integer> indexes = getIndexes(tuples.get(key), MASK);
            long delay = Long.MAX_VALUE;
            long count = Long.MAX_VALUE;
            for (int i = 0; i < 3; i++) {
                int index = indexes.get(i);
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
                result.put(key, new Pair(delay, count, avgDelay));
            } else {
//                System.out.println(key);
            }
        }
        return result;
    }

    static void checkBloomfilter(HashMap<Integer, Integer> bloomfilter, HashMap<String, Tuples> tuples) {
        Iterator<Map.Entry<String, Tuples>> iterator = tuples.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, Tuples> next = iterator.next();
            List<Integer> indexes = getIndexes(next.getValue(), bloomfilter.size() - 1);
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

    static List<Integer> getIndexes(Tuples tuples, int mask) {
        ArrayList<Long> hashList = tuples.getHash();
        ArrayList<Integer> indexes = new ArrayList<>();
        for (Long hash : hashList) {
            int index = (int) (hash & mask);
            indexes.add(index);
        }
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

    static HashMap<Integer, Pair> parse(String delayStr, String countStr, String delay_key, String count_key) {
        HashMap<Integer, Pair> hash = new HashMap<>();
        List<JSONObject> jsonDelayArray = JSON.parseArray(delayStr, JSONObject.class);
        List<JSONObject> jsonCountArray = JSON.parseArray(countStr, JSONObject.class);
        for (JSONObject jsonObject : jsonDelayArray) {
            JSONObject keyJson = (JSONObject) jsonObject.get("key");
            int index = Integer.parseInt(keyJson.get("$REGISTER_INDEX").toString());

            JSONObject dataJson = (JSONObject) jsonObject.get("data");
            String delayKey = "Egress.bf_sketch." + delay_key + ".f1";
            long delay = JSON.parseArray(dataJson.get(delayKey).toString(), Long.class).get(1);
            hash.put(index, new Pair(delay, 0, 0));
        }
        for (JSONObject jsonObject : jsonCountArray) {
            JSONObject keyJson = (JSONObject) jsonObject.get("key");
            int index = Integer.parseInt(keyJson.get("$REGISTER_INDEX").toString());

            JSONObject dataJson = (JSONObject) jsonObject.get("data");
            String countKey = "Egress.bf_sketch." + count_key + ".f1";
            long count = JSON.parseArray(dataJson.get(countKey).toString(), Long.class).get(1);
            hash.get(index).setCount(count);
        }
        return hash;
    }

    public static HashMap<String, Pair> readDelayJsonFile(String fileName) {
        try {
            HashMap<String, Pair> data = new HashMap<>();
            File file = new File(fileName);
            BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
            String line;
            while ((line = reader.readLine()) != null) {
                JSONObject tuples = (JSONObject) JSON.parse(line);
                String key = tuples.get("SrcIP") + ":" + tuples.get("SrcPort") + "->" + tuples.get("DstIP") + ":" + tuples.get("DstPort") + " " + tuples.get("Protocol");
                int value = Integer.parseInt(tuples.get("Delay").toString());
                if (data.containsKey(key)) {
                    Pair pair = data.get(key);
                    pair.setDelay(pair.getDelay() + value);
                    pair.setCount(pair.getCount() + 1);
                    pair.setAvgDelay(pair.getDelay() / pair.getCount());
                } else {
                    data.put(key, new Pair(value, 1, value));
                }
            }
            return data;
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

    public static HashMap<String, Tuples> readJsonFile(String fileName) {
        try {
            HashMap<String, Tuples> hash = new HashMap<>();
            File file = new File(fileName);
            BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
            String line;
            int count = 0;
            while ((line = reader.readLine()) != null) {
                count++;
                JSONObject tuples = (JSONObject) JSON.parse(line);
                String key = tuples.get("SrcIP") + ":" + tuples.get("SrcPort") + "->" + tuples.get("DstIP") + ":" + tuples.get("DstPort") + " " + tuples.get("Protocol");
                if (hash.containsKey(key)) {
                    continue;
                }
                long hash1 = Long.parseLong(tuples.get("HASH1").toString(), 16);
                long hash2 = Long.parseLong(tuples.get("HASH2").toString(), 16);
                long hash3 = Long.parseLong(tuples.get("HASH3").toString(), 16);
                hash.put(key, new Tuples(hash1, hash2, hash3));
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

        public Pair() {
        }

        public Pair(long delay, long count, double avgDelay) {
            this.delay = delay;
            this.count = count;
            this.avgDelay = avgDelay;
        }

        public long getDelay() {
            return delay;
        }

        public void setDelay(long delay) {
            this.delay = delay;
        }

        public long getCount() {
            return count;
        }

        public void setCount(long count) {
            this.count = count;
        }

        public double getAvgDelay() {
            return avgDelay;
        }

        public void setAvgDelay(double avgDelay) {
            this.avgDelay = avgDelay;
        }

        @Override
        public String toString() {
            return "Pair{" + "delay=" + delay + ", count=" + count + ", avgDelay=" + avgDelay + '}';
        }
    }

    static class Tuples {
        private long hash1;
        private long hash2;
        private long hash3;

        public Tuples() {
        }

        public Tuples(long hash1, long hash2, long hash3) {
            this.hash1 = hash1;
            this.hash2 = hash2;
            this.hash3 = hash3;
        }

        public ArrayList<Long> getHash() {
            ArrayList<Long> hashs = new ArrayList<Long>();
            hashs.add(hash1);
            hashs.add(hash2);
            hashs.add(hash3);
            return hashs;
        }

        public long getHash1() {
            return hash1;
        }

        public void setHash1(long hash1) {
            this.hash1 = hash1;
        }

        public long getHash2() {
            return hash2;
        }

        public void setHash2(long hash2) {
            this.hash2 = hash2;
        }

        public long getHash3() {
            return hash3;
        }

        public void setHash3(long hash3) {
            this.hash3 = hash3;
        }

        @Override
        public String toString() {
            return "Tuples{" + "hash1=" + hash1 + ", hash2=" + hash2 + ", hash3=" + hash3 + '}';
        }
    }
}