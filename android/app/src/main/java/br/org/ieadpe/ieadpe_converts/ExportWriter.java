package br.org.ieadpe.ieadpe_converts;

import java.io.IOException;
import java.io.OutputStream;

/** Requires a real stream and returns only after write, flush and close succeed. */
public final class ExportWriter {
    private ExportWriter() {}
    public interface OpenStream { OutputStream open() throws IOException; }
    public static void write(OpenStream opener, byte[] bytes) throws IOException {
        try (OutputStream stream = opener.open()) {
            if (stream == null) throw new IOException("Unable to open destination");
            stream.write(bytes);
            stream.flush();
        }
    }
}
