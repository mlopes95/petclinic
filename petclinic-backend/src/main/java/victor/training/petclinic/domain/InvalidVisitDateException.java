package victor.training.petclinic.domain;

public class InvalidVisitDateException extends RuntimeException {
    public InvalidVisitDateException(String message) {
        super(message);
    }
}
