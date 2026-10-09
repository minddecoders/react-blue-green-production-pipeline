import style from './home.module.css';
import image from '../assets/image.png';
import profile from '../assets/Muslim girl animation.jpg';
 import {useState} from 'react';
function Home(){
    const [show,setShow]=useState(false)
    function togglePopup(){
    document.getElementById("popup")
    .classList.toggle("show");
}

 return(
   <div className={style.home}>
    <div className={style.container} >
        <img src={image} alt='profile' ></img>

       <div className={style.about}>
    <h1>
Welcome to Green Version 2
</h1>
       <p>Ever been in a room and felt like something was missing? Perhaps it felt slightly bare and uninviting. I’ve got some simple tips to help you make any room feel complete.</p>
       <div className={style.profile}>
      <img src={profile} alt='profile'></img>
      <div>
      <h2>Michelle Appleton</h2>
      <p>28 July 2026</p>
      </div>
     <button
        className={style.sharebtn}
        onClick={togglePopup}
      >Share
   {show && (
        <div className={style.popup}>
          <span>SHARE</span>
          <i>Facebook</i>
          <i>Twitter</i>
          <i>Pinterest</i>
        </div>
      )}
      </button>
        </div>
        </div>
    </div>
   </div>
    )
}
export default Home;