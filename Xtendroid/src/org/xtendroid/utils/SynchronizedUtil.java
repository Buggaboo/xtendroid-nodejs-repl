package org.xtendroid.utils;

import org.eclipse.xtext.xbase.lib.Inline;
import org.eclipse.xtext.xbase.lib.Procedures;

/**
 * Helper for synchronizing on an object. Use as follows:
 * 
 *    import static org.xtendroid.utils.SynchonizedUtil.*
 * 
 *    sync(obj) [
 *       // do stuff
 *    ]
 * 
 * @see https://bugs.eclipse.org/bugs/show_bug.cgi?id=418753
 */
public class SynchronizedUtil {
   /**
    * @deprecated synchronized expression is supported natively since Xtend 2.6 
    */
   @Deprecated
   @Inline(value = "synchronized($1) { $2.apply($1);}", statementExpression = true)
   public static <T> void sync(T obj, Procedures.Procedure1<? super T> proc) {
      synchronized (obj) {
         proc.apply(obj);
      }
   }
}
