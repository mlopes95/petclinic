package victor.training.petclinic.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.repository.Repository;
import victor.training.petclinic.domain.Owner;

public interface OwnerRepository extends Repository<Owner, Integer> {

    /**
     * Case-insensitive "contains" over every column the owners table shows: the full name as
     * one cell, address, city, telephone, and the names of the owner's pets. An empty term matches
     * everyone, since every value contains the empty string.
     * <p>
     * The pets join decides <em>which owners</em> match and must stay a plain join: turning it
     * into a JOIN FETCH would narrow each owner's pets to the ones matching the term.
     */
    @Query("""
            SELECT DISTINCT o FROM Owner o
            LEFT JOIN o.pets p
            WHERE LOWER(CONCAT(o.firstName, ' ', o.lastName)) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
               OR LOWER(o.address) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
               OR LOWER(o.city) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
               OR LOWER(o.telephone) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
               OR LOWER(p.name) LIKE LOWER(CONCAT('%', :searchTerm, '%'))
            ORDER BY o.lastName, o.firstName
            """)
    List<Owner> search(@Param("searchTerm") String searchTerm);

    Optional<Owner> findById(int id);

    @Query("SELECT o FROM Owner o LEFT JOIN FETCH o.pets WHERE o.id = :id")
    Optional<Owner> findByIdFetchingPets(int id);

    Owner save(Owner owner);

    void delete(Owner owner);

    long count();

}
