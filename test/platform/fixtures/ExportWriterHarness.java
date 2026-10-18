import br.org.ieadpe.ieadpe_converts.ExportWriter;
import java.io.*;
import java.util.Arrays;
public class ExportWriterHarness {
 public static void main(String[] args) throws Exception {
  boolean rejected=false;
  try { ExportWriter.write(()->null,new byte[]{1}); } catch(IOException e) {rejected=true;}
  if(!rejected)throw new AssertionError("Null stream must fail");
  final boolean[] closed={false};
  ByteArrayOutputStream stream=new ByteArrayOutputStream(){public void close() throws IOException {closed[0]=true;super.close();}};
  ExportWriter.write(()->stream,new byte[]{65,66});
  if(!Arrays.equals(stream.toByteArray(),new byte[]{65,66}) || !closed[0])throw new AssertionError("Bytes must be written and closed before success");
  rejected=false;
  try {ExportWriter.write(()->new ByteArrayOutputStream(){public void close() throws IOException{throw new IOException("close failed");}},new byte[]{1});}catch(IOException e){rejected=true;}
  if(!rejected)throw new AssertionError("Close failure must fail");
  rejected=false;
  try {ExportWriter.write(()->new OutputStream(){public void write(int value)throws IOException{throw new IOException("write failed");}},new byte[]{1});}catch(IOException e){rejected=true;}
  if(!rejected)throw new AssertionError("Write failure must fail");
  System.out.println("null-stream, bytes, close and write failures verified");
 }
}
