package com.linapps.releaseqa;
import com.android.uiautomator.testrunner.UiAutomatorTestCase;
import com.android.uiautomator.core.UiObject;
import com.android.uiautomator.core.UiSelector;
import com.android.uiautomator.core.UiScrollable;
import java.io.File;

/** Standalone Android UI harness: no classes are loaded from the optimized app. */
public class ReleaseUiSmoke extends UiAutomatorTestCase {
  UiObject item(String text) {return new UiObject(new UiSelector().text(text));}
  UiObject contains(String text) {return new UiObject(new UiSelector().textContains(text));}
  void click(UiObject object) throws Exception {if(!object.waitForExists(1000)) {UiScrollable scroll=new UiScrollable(new UiSelector().scrollable(true));if(scroll.waitForExists(1000)) scroll.scrollIntoView(object.getSelector());}assertTrue("Release control missing: "+object.getSelector(),object.waitForExists(30000));object.click();}
  public void testProductionPayload() throws Exception {
    String app=getParams().getString("app");String language=getParams().getString("language");
    assertTrue(app.equals("com.linapps.ykiflashcards") || app.equals("com.linapps.swedish3000"));
    Process launch=Runtime.getRuntime().exec(new String[]{"/system/bin/am","start","-W","-n",app+"/.MainActivity"});
    while(launch.getInputStream().read()!=-1){};assertEquals(0,launch.waitFor());
    click(item("Words"));
    UiObject back=contains("‹ Topics");
    if(back.waitForExists(1500)) back.click();
    assertTrue("Vocabulary library missing",item("Your vocabulary").waitForExists(30000));
    click(item("Filters"));assertTrue(item("All topics").waitForExists(30000));
    click(contains("Home & living"));click(new UiObject(new UiSelector().textStartsWith("Show ").textContains("words")));
    click(item("Settings"));assertTrue(contains("3000 "+language+" Words Free").waitForExists(30000));
    click(contains("Word reminders"));assertTrue(item("Try the complete A set free").waitForExists(30000));
    assertFalse("Free must not reach the reminder editor",item("Save reminders").exists());click(item("Done"));
    click(contains("Download for offline study"));assertTrue(new UiObject(new UiSelector().textStartsWith("Free A-set lessons:")).waitForExists(30000));
    click(item("Done"));click(item("Progress"));assertTrue(item("Your progress").waitForExists(30000));
    assertTrue(item("Currently learning").waitForExists(30000));
    getUiDevice().takeScreenshot(new File("/data/local/tmp/"+language.toLowerCase()+"-release-progress.png"));
  }
}
