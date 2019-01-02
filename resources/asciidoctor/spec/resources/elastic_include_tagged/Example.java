
public class Example {
    public void doThings() {
        // tag::t1
        System.err.println("I'm an example");
        for (int i = 0; i < 10; i++) {
            System.err.println(i); // <1>
        }
        // end::t1

        // tag::t2
        System.err.println("I'm another example");
        // end::t2

        // tag::empty
        // end::empty

        //tag::no_leading_space
        System.err.println("no leading space");
        //end::no_leading_space

        // end::missing-start

        // tag::missing-end
        System.err.println("this tag doesn't have any end");
    }
}
