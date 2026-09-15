package NocTb;

import Vector::*;
import GetPut::*;
import Noc::*;

// 2×2 网格全对全、饱和不死锁，外加点对点。每个报文的负载是这条「源到目的」上的序号，
// 接收端逐个核对目的号与序号，最后核对个数。
(* synthesize *)
module mkNocTb(Empty);
  Mesh#(2, 2) mesh = Mesh;
  P2P         link = P2P;
  Network#(4, 16) net <- mkNetwork(mesh);
  Network#(2, 16) pp  <- mkNetwork(link);

  Reg#(UInt#(32)) cyc <- mkReg(0);
  rule count;
    cyc <= cyc + 1;
  endrule

  // ---- 网格：每个节点给其余三个各发 20 个，共 60 个 ----
  Vector#(4, Reg#(UInt#(8)))                sent <- replicateM(mkReg(0));
  Vector#(4, Vector#(4, Reg#(UInt#(8))))    got  <- replicateM(replicateM(mkReg(0)));
  Vector#(4, Reg#(Bool))                    badM <- replicateM(mkReg(False));

  for (Integer s = 0; s < 4; s = s + 1)
    rule send (sent[s] < 60);
      UInt#(8) k = sent[s];
      UInt#(8) d = (fromInteger(s) + 1 + (k % 3)) % 4;
      net.inject[s].put(Pkt { dest: d, src: fromInteger(s), payload: zeroExtend(pack(k / 3)) });
      sent[s] <= k + 1;
    endrule

  // 0 号与 3 号节点前 300 拍不收：网格里的缓冲塞满，看恢复之后会不会卡死
  for (Integer d = 0; d < 4; d = d + 1)
    rule recv ((d != 0 && d != 3) || cyc > 300);
      let p <- net.deliver[d].get;
      Bool wrong = False;
      if (p.dest != fromInteger(d)) begin
        $display("FAIL node %0d received a packet addressed to node %0d", d, p.dest);
        wrong = True;
      end else if (p.payload != zeroExtend(pack(got[d][p.src]))) begin
        $display("FAIL node %0d got packet %0d from node %0d, want %0d", d, p.payload, p.src, got[d][p.src]);
        wrong = True;
      end
      got[d][p.src] <= got[d][p.src] + 1;
      if (wrong) badM[d] <= True;
    endrule

  // ---- 点对点：两个节点互发 50 个 ----
  Vector#(2, Reg#(UInt#(8))) sentP <- replicateM(mkReg(0));
  Vector#(2, Reg#(UInt#(8))) gotP  <- replicateM(mkReg(0));
  Vector#(2, Reg#(Bool))     badP  <- replicateM(mkReg(False));

  for (Integer s = 0; s < 2; s = s + 1) begin
    rule sendP (sentP[s] < 50);
      pp.inject[s].put(Pkt { dest: fromInteger(1 - s), src: fromInteger(s), payload: zeroExtend(pack(sentP[s])) });
      sentP[s] <= sentP[s] + 1;
    endrule
    rule recvP;
      let p <- pp.deliver[s].get;
      if (p.dest != fromInteger(s) || p.payload != zeroExtend(pack(gotP[s]))) begin
        $display("FAIL point-to-point node %0d got packet %0d addressed to %0d, want %0d", s, p.payload, p.dest, gotP[s]);
        badP[s] <= True;
      end
      gotP[s] <= gotP[s] + 1;
    endrule
  end

  function Bool meshDone;
    Bool all = True;
    for (Integer d = 0; d < 4; d = d + 1)
      for (Integer s = 0; s < 4; s = s + 1)
        if (s != d && got[d][s] != 20) all = False;
    return all;
  endfunction

  rule finish (meshDone && gotP[0] == 50 && gotP[1] == 50 || cyc > 20000);
    Bool wrong = False;
    for (Integer d = 0; d < 4; d = d + 1) begin
      for (Integer s = 0; s < 4; s = s + 1)
        if (s != d && got[d][s] != 20) begin
          $display("FAIL only %0d of 20 packets from node %0d reached node %0d", got[d][s], s, d);
          wrong = True;
        end
      if (badM[d]) wrong = True;
    end
    for (Integer s = 0; s < 2; s = s + 1) begin
      if (gotP[s] != 50) begin
        $display("FAIL only %0d of 50 point-to-point packets reached node %0d", gotP[s], s);
        wrong = True;
      end
      if (badP[s]) wrong = True;
    end
    if (wrong) $display("FAILED");
    else $display("PASS noc: a 2x2 mesh delivers every packet of an all-to-all pattern in order, recovers from "
                  + "two receivers stalling for 300 cycles without deadlock, and a point-to-point link delivers both ways");
    $finish(wrong ? 1 : 0);
  endrule
endmodule

endpackage
