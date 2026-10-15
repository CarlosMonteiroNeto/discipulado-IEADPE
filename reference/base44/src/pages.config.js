import Admin from './pages/Admin';
import Converts from './pages/Converts';
import Home from './pages/Home';
import Register from './pages/Register';
import __Layout from './Layout.jsx';


export const PAGES = {
    "Admin": Admin,
    "Converts": Converts,
    "Home": Home,
    "Register": Register,
}

export const pagesConfig = {
    mainPage: "Register",
    Pages: PAGES,
    Layout: __Layout,
};