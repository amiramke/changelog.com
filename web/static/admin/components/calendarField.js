export default class CalendarField {
  constructor(selector) {
    let tz = new Date().toLocaleTimeString("en-us", {timeZoneName: "short"}).split(" ")[2];

    $(selector).calendar({
      today: true,
      selector: {
        popup: ".ui.popup",
        input: "input[type=text]",
        activator: "input"
      },
      parser: {
        date: function(text, settings) {
          return new Date(text);
        }
      },
      formatter: {
        time: function (date, settings, forCalendar) {
          if (!date) return "";
          var hour = date.getHours();
          var minute = date.getMinutes();
          var ampm = hour < 12 ? "AM" : "PM";
          hour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
          return `${hour}:${(minute < 10 ? "0" : "")}${minute} ${ampm} (${tz})`;
        }
      },
      onChange: function(date, text) {
        $(this).find("input[type=hidden]").val(date.toISOString());
      }
    });
  }
}