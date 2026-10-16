package br.org.ieadpe.ieadpe_converts;

import java.text.Collator;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Platform locale ordering shared by the Android channel and JVM checks. */
public final class PortugueseCollation {
    public static List<String> sort(List<String> names) {
        Collator collator = Collator.getInstance(Locale.forLanguageTag("pt-BR"));
        collator.setStrength(Collator.TERTIARY);
        collator.setDecomposition(Collator.CANONICAL_DECOMPOSITION);
        List<String> result = new ArrayList<>(names);
        result.sort(collator);
        return result;
    }
}
