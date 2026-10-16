import br.org.ieadpe.ieadpe_converts.PortugueseCollation;
import java.util.Arrays;
import java.util.List;

public class PortugueseCollationCheck {
    public static void main(String[] args) {
        List<String> input=Arrays.asList("São","Sao","são","sao","Sede","Sede Nova","área","Área","Area","area","Ação","Acao","ação","Zebra","Água");
        List<String> expected=Arrays.asList("Acao","ação","Ação","Água","area","Area","área","Área","sao","Sao","são","São","Sede","Sede Nova","Zebra");
        List<String> actual=PortugueseCollation.sort(input);
        if(!actual.equals(expected)) throw new AssertionError("Unexpected pt-BR ordering: "+actual);
        if(!PortugueseCollation.sort(Arrays.asList("Sa\u0303o","São")).equals(Arrays.asList("Sa\u0303o","São"))) throw new AssertionError("Canonical equivalence lost");
        System.out.println("PASS: production Java Collator matches pt-BR accent/case and canonical-equivalence fixtures");
    }
}
